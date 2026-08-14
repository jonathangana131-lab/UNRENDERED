from __future__ import annotations

import json
import unittest

import event_producer


class EventProducerFenceTests(unittest.TestCase):
    def base(self):
        return {
            "schemaVersion": 1,
            "eventId": "evt-20260814-081500-v162-producer",
            "timestamp": "2026-08-14T08:15:00Z",
            "fromWorker": "sol-20260814-v162evt",
            "eventType": "FINDING",
            "summary": "producer fence test",
            "affects": [],
        }

    def publish(self, payload):
        calls = []
        result = event_producer.publish_validated_event(payload, lambda raw: calls.append(raw) or raw)
        return calls, result

    def test_valid_event_reaches_sink_once(self):
        payload = self.base()
        calls, result = self.publish(payload)
        self.assertEqual(len(calls), 1)
        self.assertEqual(result, calls[0])
        self.assertEqual(json.loads(result)["eventId"], payload["eventId"])

    def test_top_level_pr_is_rejected_before_sink_for_finding(self):
        payload = self.base(); payload["pr"] = 480
        calls = []
        with self.assertRaises(event_producer.EventProductionError):
            event_producer.publish_validated_event(payload, lambda raw: calls.append(raw))
        self.assertEqual(calls, [])

    def test_top_level_head_sha_is_rejected_before_sink_for_finding(self):
        payload = self.base(); payload["headSha"] = "a" * 40
        calls = []
        with self.assertRaises(event_producer.EventProductionError):
            event_producer.publish_validated_event(payload, lambda raw: calls.append(raw))
        self.assertEqual(calls, [])

    def test_top_level_recommendation_is_rejected_before_sink(self):
        payload = self.base(); payload["recommendation"] = "merge"
        calls = []
        with self.assertRaises(event_producer.EventProductionError):
            event_producer.publish_validated_event(payload, lambda raw: calls.append(raw))
        self.assertEqual(calls, [])

    def test_context_fields_belong_under_metadata(self):
        payload = self.base()
        payload["metadata"] = {"pr": 480, "headSha": "a" * 40, "recommendation": "merge after review"}
        calls, _ = self.publish(payload)
        self.assertEqual(len(calls), 1)

    def test_typed_review_result_keeps_existing_strict_exception(self):
        payload = self.base()
        payload.update({
            "eventType": "REVIEW_RESULT",
            "pr": 480,
            "headSha": "a" * 40,
            "verdict": "APPROVE",
        })
        calls, _ = self.publish(payload)
        self.assertEqual(len(calls), 1)

    def test_partial_typed_review_fields_are_rejected_before_sink(self):
        payload = self.base(); payload.update({"eventType": "REVIEW_RESULT", "pr": 480})
        calls = []
        with self.assertRaises(event_producer.EventProductionError):
            event_producer.publish_validated_event(payload, lambda raw: calls.append(raw))
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
