from __future__ import annotations

import unittest

from foundry_v17 import FoundryPolicyError, RepositoryPressure, admission_plan


class FoundryV17Tests(unittest.TestCase):
    def test_audited_unrendered_pressure_denies_branch_multiplication(self):
        plan = admission_plan(
            requested_workers=30,
            ready_builders=20,
            active_builders=2,
            review_backlog=10,
            integration_backlog=6,
            retirement_candidates=80,
            pressure=RepositoryPressure(open_product_prs=100, open_branches=971),
        )
        self.assertEqual(plan["status"], "RETIREMENT")
        self.assertEqual(plan["newPrimaryBuilders"], 0)
        self.assertGreater(plan["retirementWorkers"], 0)
        self.assertFalse(plan["authorityGranted"])

    def test_red_main_allows_only_one_emergency_builder_over_budget(self):
        plan = admission_plan(
            requested_workers=30,
            ready_builders=12,
            active_builders=0,
            review_backlog=0,
            integration_backlog=0,
            retirement_candidates=80,
            pressure=RepositoryPressure(open_product_prs=100, open_branches=971),
            red_main=True,
        )
        self.assertEqual(plan["newPrimaryBuilders"], 1)
        self.assertTrue(plan["redMainEmergencyException"])

    def test_workers_are_not_a_fixed_quota(self):
        plan = admission_plan(
            requested_workers=30,
            ready_builders=2,
            active_builders=0,
            review_backlog=1,
            integration_backlog=1,
            retirement_candidates=0,
            pressure=RepositoryPressure(open_product_prs=2, open_branches=3),
        )
        self.assertEqual(plan["newPrimaryBuilders"], 2)
        self.assertEqual(plan["consideredWorkers"], 20)
        self.assertLess(plan["admittedWorkers"], 30)

    def test_integration_pressure_throttles_new_builders(self):
        plan = admission_plan(
            requested_workers=30,
            ready_builders=15,
            active_builders=0,
            review_backlog=4,
            integration_backlog=3,
            retirement_candidates=0,
            pressure=RepositoryPressure(open_product_prs=1, open_branches=2),
        )
        self.assertEqual(plan["newPrimaryBuilders"], 1)
        self.assertEqual(plan["integrators"], 3)

    def test_invalid_pressure_fails_closed(self):
        with self.assertRaises(FoundryPolicyError):
            admission_plan(
                requested_workers=30,
                ready_builders=1,
                active_builders=0,
                review_backlog=0,
                integration_backlog=0,
                retirement_candidates=0,
                pressure=RepositoryPressure(open_product_prs=0, open_branches=-1),
            )


if __name__ == "__main__":
    unittest.main()
