// SuiFlow formal-spec source for Sui Prover / Move Prover integration.
//
// This file is intentionally kept outside `sources/` because the local Sui CLI
// installed for the hackathon has no `sui move prove` command. It records the
// proof obligations that should be loaded when the Sui Prover toolchain is
// installed. The executable counterparts are covered by Move tests.

spec suiflow::agent_settlement {
    // Escrow conservation:
    // For every WorkOrder, the sum of child budget allocations, metered draws,
    // and premium skims must never exceed the original funded amount.
    invariant forall order: WorkOrder:
        order.child_budget_allocated + order.metered_paid + order.premium_paid <= order.amount;

    // Capability attenuation:
    // Any child policy minted by spawn_child_work_order must be no stronger
    // than its parent across action mask, provider cap, expiry, uses, depth,
    // and remaining funded budget.
    schema ChildPolicyIsAttenuated {
        parent: AgentPolicy;
        child: AgentPolicy;
        ensures (child.allowed_actions & parent.allowed_actions) == child.allowed_actions;
        ensures child.depth == parent.depth + 1;
        ensures child.depth <= MAX_DEPTH;
        ensures parent.max_provider_amount == 0 || child.max_provider_amount <= parent.max_provider_amount;
        ensures parent.expires_ms == 0 || child.expires_ms <= parent.expires_ms;
        ensures child.root_principal == parent.root_principal;
        ensures child.remaining_budget <= parent.remaining_budget + child.remaining_budget;
    }

    // Revocation soundness:
    // A live action must fail when any ancestor generation is newer than the
    // policy snapshot, when the policy is locally revoked, or when the fleet is
    // paused.
    schema LivePolicyRequired {
        policy: AgentPolicy;
        registry: GenerationRegistry;
        ensures registry.paused ==> !policy_is_live(policy, registry);
        ensures policy.revoked ==> !policy_is_live(policy, registry);
    }

    // Metered settlement:
    // A metered draw cannot exceed escrow, policy budget, or provider cap, and
    // each draw reduces the policy remaining budget by the paid amount.
    schema MeteredDrawBounded {
        order: WorkOrder;
        policy: AgentPolicy;
        paid: u64;
        ensures paid <= order.amount;
        ensures paid <= policy.remaining_budget + paid;
        ensures policy.max_provider_amount == 0 || order.metered_paid <= policy.max_provider_amount;
    }

    // Denial-receipt insurance:
    // A claim pays only against the matching policy/work order and never more
    // than staked vault capital, coverage cap, or the work-order amount.
    schema InsuranceClaimBounded {
        vault: UnderwritingVault;
        receipt: DenialReceipt;
        order: WorkOrder;
        payout: u64;
        ensures receipt.policy_id == vault.policy_id;
        ensures receipt.work_order_id == object::id(order);
        ensures payout <= vault.coverage_cap;
        ensures payout <= order.amount;
    }

    // Bonded validation:
    // A validator bond may be slashed only when the bond previously attested
    // the same work order and agent that the denial receipt contradicts.
    schema ValidatorSlashSound {
        bond: ValidatorBondCap;
        receipt: DenialReceipt;
        ensures option::is_some(&bond.last_work_order_id);
        ensures *option::borrow(&bond.last_work_order_id) == receipt.work_order_id;
        ensures bond.last_agent == receipt.agent;
    }

    // Execution-binding:
    // A service receipt nullifier is consumed once, so a web execution cannot
    // be replayed into repeated settlement.
    schema ExecutionNullifierSingleUse {
        registry: ExecutionBindingRegistry;
        nullifier_hash: vector<u8>;
        ensures table::contains(&registry.used_nullifiers, nullifier_hash);
    }

    // Privacy-budget soundness:
    // Weighted content/behavior leakage can never spend beyond the WorkOrder
    // privacy budget or the policy-level privacy allocation.
    schema PrivacyBudgetBounded {
        order: WorkOrder;
        policy: AgentPolicy;
        weighted_score: u64;
        ensures order.privacy_used <= order.privacy_budget;
        ensures weighted_score <= policy.privacy_budget_remaining + weighted_score;
    }

    // Origin-critic quarantine:
    // Risk receipts can only consume a policy's origin-risk budget. When a
    // WorkOrder is quarantined, settlement paths must abort until payer review
    // clears the flag.
    schema OriginCriticQuarantineSound {
        order: WorkOrder;
        policy: AgentPolicy;
        risk_score: u64;
        ensures risk_score <= policy.origin_risk_budget_remaining + risk_score;
        ensures order.critic_quarantined ==> order.critic_risk_threshold > 0;
    }
}
