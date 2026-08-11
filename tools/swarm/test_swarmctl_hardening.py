#!/usr/bin/env python3
import json
import tempfile
import unittest
from pathlib import Path

import swarmctl as core
import swarmctl_hardening as hard

NOW = "2026-08-11T05:00:00+00:00"


def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n")


def config():
    return {
        "schemaVersion": 1, "controlBranch": "swarm-control", "description": "test",
        "leaseDefaults": {"primary": 1800, "review": 1200, "evidence": 2400, "integration": 1200},
        "wip": {"maxMajorEpics": 5, "maxPrimaryImplementationLanes": 8, "reviewBacklogThrottle": 4, "integrationBacklogThrottle": 3},
        "scheduler": {"redMainOverride": True, "idleAllowed": True, "requireValidatedState": False},
        "protectedScopes": [{"pattern": "src/shared/Reality/**", "resource": "REALITY-CONTRACT"}],
    }


def lane(lid="LANE-A", state="READY", epic="EPIC-A", resources=None, scopes=None, tags=None):
    obj = {
        "schemaVersion": 1, "laneId": lid, "epicId": epic, "title": lid,
        "objective": "Hardening test lane.", "priority": 1000, "state": state, "mode": "exclusive",
        "dependencies": [], "writeScopes": scopes or ["src/server/Test/**"], "resources": resources or [],
        "slots": [
            {"slotId":"primary","role":"Primary implementation","exclusive":True,"availableWhen":["READY","NEEDS_CHANGES"],"priorityBoost":0},
            {"slotId":"reviewer-1","role":"Independent review","exclusive":True,"availableWhen":["REVIEW"],"requiresIndependentFrom":"primary","priorityBoost":100},
            {"slotId":"integration","role":"Integration","exclusive":True,"availableWhen":["INTEGRATION_READY"],"requiresIndependentFrom":"primary","priorityBoost":200},
        ],
        "acceptance": ["proof"],
    }
    if tags is not None: obj["tags"] = tags
    return obj


def claim(worker="sol-20260811-a81f", token="a"*16, generation=1, heartbeat="2026-08-11T04:50:00+00:00", claimed="2026-08-11T04:40:00+00:00", resources=None, pr=None):
    return {
        "schemaVersion":1,"laneId":"LANE-A","slotId":"primary","workerId":worker,"claimToken":token,
        "claimedAt":claimed,"heartbeatAt":heartbeat,"leaseSeconds":1800,"generation":generation,
        "resources":resources or [],"branch":f"agent/test/LANE-A-{worker[-4:]}","pr":pr,
    }


def rclaim(rid="REALITY-CONTRACT", worker="sol-20260811-a81f", token="a"*16, generation=1, heartbeat="2026-08-11T04:50:00+00:00", acquired="2026-08-11T04:40:00+00:00"):
    return {"schemaVersion":1,"resourceId":rid,"workerId":worker,"laneId":"LANE-A","claimToken":token,"acquiredAt":acquired,"heartbeatAt":heartbeat,"leaseSeconds":1800,"generation":generation}


def worker(wid="sol-20260811-a81f", status="WORKING", branch="agent/test/LANE-A-a81f"):
    return {"schemaVersion":1,"workerId":wid,"model":"gpt-5.6-sol","status":status,"startedAt":"2026-08-11T04:30:00+00:00","lastSeenAt":"2026-08-11T04:50:00+00:00","laneId":"LANE-A","slotId":"primary","branch":branch}


def resource(rid="REALITY-CONTRACT"):
    return {"schemaVersion":1,"resourceId":rid,"state":"AVAILABLE","mode":"exclusive","order":10,"capacity":1,"description":"test"}


class Fx:
    def __init__(self):
        self.t=tempfile.TemporaryDirectory(); self.root=Path(self.t.name)/".swarm"
        for d in ["lanes","resources","claims","resource-claims","workers","events","generated","health"]: (self.root/d).mkdir(parents=True,exist_ok=True)
        write(self.root/"config.json",config())
    def lane(self,o): write(self.root/"lanes"/f"{o['laneId']}.json",o)
    def resource(self,o): write(self.root/"resources"/f"{o['resourceId']}.json",o)
    def claim(self,o): write(self.root/"claims"/o["laneId"]/f"{o['slotId']}.json",o)
    def rclaim(self,o): write(self.root/"resource-claims"/f"{o['resourceId']}.json",o)
    def worker(self,o): write(self.root/"workers"/f"{o['workerId']}.json",o)
    def close(self): self.t.cleanup()


class HardeningTests(unittest.TestCase):
    def setUp(self): self.fx=Fx(); self.now=core.parse_time(NOW)
    def tearDown(self): self.fx.close()

    def test_claim_can_wait_for_resource_without_invalidating_control_state(self):
        self.fx.resource(resource()); self.fx.lane(lane(resources=["REALITY-CONTRACT"])); self.fx.claim(claim(resources=["REALITY-CONTRACT"]))
        hard.validate_all(self.fx.root,self.now)

    def test_pr_requires_every_declared_resource_lease(self):
        self.fx.resource(resource()); self.fx.lane(lane(resources=["REALITY-CONTRACT"],scopes=["src/server/Test/**"])); self.fx.claim(claim(resources=["REALITY-CONTRACT"])); self.fx.worker(worker())
        ep=self.fx.root.parent/"event.json"; cp=self.fx.root.parent/"changed.txt"
        write(ep,{"pull_request":{"number":1,"body":"Swarm-Lane: LANE-A\nSwarm-Slot: primary\nSwarm-Worker: sol-20260811-a81f\nSwarm-Claim-Token: aaaaaaaaaaaaaaaa\nControl-Schema: 1","head":{"ref":"agent/test/LANE-A-a81f"}}}); cp.write_text("src/server/Test/Foo.luau\n")
        with self.assertRaises(core.ControlError): hard.pr_check(self.fx.root,ep,cp,self.now)

    def test_stopped_worker_is_fenced_from_pr(self):
        self.fx.lane(lane()); c=claim(); c["branch"]="agent/test/LANE-A-a81f"; self.fx.claim(c); self.fx.worker(worker(status="STOPPED"))
        ep=self.fx.root.parent/"event.json"; cp=self.fx.root.parent/"changed.txt"
        write(ep,{"pull_request":{"number":1,"body":"Swarm-Lane: LANE-A\nSwarm-Slot: primary\nSwarm-Worker: sol-20260811-a81f\nSwarm-Claim-Token: aaaaaaaaaaaaaaaa\nControl-Schema: 1","head":{"ref":"agent/test/LANE-A-a81f"}}}); cp.write_text("src/server/Test/Foo.luau\n")
        with self.assertRaises(core.ControlError): hard.pr_check(self.fx.root,ep,cp,self.now)

    def test_claim_attached_to_other_pr_is_rejected(self):
        self.fx.lane(lane()); c=claim(pr=7); c["branch"]="agent/test/LANE-A-a81f"; self.fx.claim(c); self.fx.worker(worker())
        ep=self.fx.root.parent/"event.json"; cp=self.fx.root.parent/"changed.txt"
        write(ep,{"pull_request":{"number":8,"body":"Swarm-Lane: LANE-A\nSwarm-Slot: primary\nSwarm-Worker: sol-20260811-a81f\nSwarm-Claim-Token: aaaaaaaaaaaaaaaa\nControl-Schema: 1","head":{"ref":"agent/test/LANE-A-a81f"}}}); cp.write_text("src/server/Test/Foo.luau\n")
        with self.assertRaises(core.ControlError): hard.pr_check(self.fx.root,ep,cp,self.now)

    def test_validation_digest_fences_unvalidated_mutation(self):
        self.fx.lane(lane()); board=hard.render(self.fx.root,self.now); hard.validate_marker(self.fx.root)
        obj=lane(); obj["priority"]=9999; self.fx.lane(obj)
        with self.assertRaises(core.ControlError): hard.validate_marker(self.fx.root)
        self.assertEqual(board["stateDigest"], json.loads((self.fx.root/"generated/validation.json").read_text())["stateDigest"])

    def test_generated_projection_is_excluded_from_digest(self):
        self.fx.lane(lane()); a=hard.state_digest(self.fx.root); write(self.fx.root/"generated/x.json",{"x":1}); b=hard.state_digest(self.fx.root); self.assertEqual(a,b)

    def test_takeover_before_expiry_rejected(self):
        b=Fx(); a=Fx()
        try:
            b.lane(lane()); a.lane(lane()); b.claim(claim())
            n=claim(worker="sol-20260811-bb22",token="b"*16,generation=2,heartbeat="2026-08-11T04:55:00+00:00",claimed="2026-08-11T04:55:00+00:00"); n["takeoverOf"]="sol-20260811-a81f"; a.claim(n)
            with self.assertRaises(core.ControlError): hard.transition_check(b.root,a.root)
        finally: b.close(); a.close()

    def test_stale_takeover_requires_generation_and_previous_worker(self):
        b=Fx(); a=Fx()
        try:
            b.lane(lane()); a.lane(lane()); b.claim(claim(heartbeat="2026-08-11T03:00:00+00:00",claimed="2026-08-11T02:50:00+00:00"))
            n=claim(worker="sol-20260811-bb22",token="b"*16,generation=2,heartbeat="2026-08-11T04:50:00+00:00",claimed="2026-08-11T04:50:00+00:00"); n["takeoverOf"]="sol-20260811-a81f"; a.claim(n)
            self.assertEqual(hard.transition_check(b.root,a.root)["status"],"PASS")
        finally: b.close(); a.close()

    def test_immutable_event_rewrite_rejected(self):
        b=Fx(); a=Fx()
        try:
            e={"schemaVersion":1,"eventId":"evt-20260811-050000-immut","timestamp":NOW,"fromWorker":"sol-20260811-a81f","eventType":"FINDING","summary":"one","affects":[]}; write(b.root/"events/2026-08-11/e.json",e); e["summary"]="two"; write(a.root/"events/2026-08-11/e.json",e)
            with self.assertRaises(core.ControlError): hard.transition_check(b.root,a.root)
        finally: b.close(); a.close()

    def test_red_main_only_schedules_repair_tag(self):
        self.fx.lane(lane("NORMAL")); self.fx.lane(lane("REPAIR",tags=["red-main"])); write(self.fx.root/"health/main.json",{"schemaVersion":1,"status":"RED","headSha":"a"*40,"workflowRunId":9,"updatedAt":NOW,"conclusion":"failure"})
        ids={x["laneId"] for x in hard.render_board(self.fx.root,self.now)["readySlots"]}; self.assertEqual(ids,{"REPAIR"})

    def test_integration_backlog_throttles_new_primary(self):
        cfg=config(); cfg["wip"]["integrationBacklogThrottle"]=1; write(self.fx.root/"config.json",cfg); self.fx.lane(lane("MERGE",state="INTEGRATION_READY")); self.fx.lane(lane("NEW")); slots=hard.render_board(self.fx.root,self.now)["readySlots"]; self.assertFalse(any(x["laneId"]=="NEW" and x["slotId"]=="primary" for x in slots)); self.assertTrue(any(x["laneId"]=="MERGE" and x["slotId"]=="integration" for x in slots))

    def test_major_epic_wip_is_enforced(self):
        cfg=config(); cfg["wip"]["maxMajorEpics"]=1; write(self.fx.root/"config.json",cfg); self.fx.lane(lane("A-LANE",epic="EPIC-A")); self.fx.lane(lane("B-LANE",epic="EPIC-B"));
        with self.assertRaises(core.ControlError): hard.validate_all(self.fx.root,self.now)

    def test_sync_main_health_opens_and_closes_repair_lane(self):
        self.fx.lane(lane("OPS-MAIN-HEALTH",state="DONE",tags=["red-main","control-repair"])); hard.sync_main_health(self.fx.root,"c"*40,"failure",123,NOW); self.assertEqual(json.loads((self.fx.root/"lanes/OPS-MAIN-HEALTH.json").read_text())["state"],"READY"); hard.sync_main_health(self.fx.root,"c"*40,"success",124,NOW); self.assertEqual(json.loads((self.fx.root/"lanes/OPS-MAIN-HEALTH.json").read_text())["state"],"DONE")


if __name__ == "__main__": unittest.main()
