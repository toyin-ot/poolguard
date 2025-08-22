# PoolGuard - Decentralized Insurance Pool

## Overview
PoolGuard is a smart contract implementing a fully decentralized insurance pool on the Stacks blockchain. It enables users to participate in a collective insurance system where members can contribute funds, purchase policies, submit claims, and participate in democratic claim resolution through voting.

## Features
- **Pool Contributions**: Members can contribute STX tokens to the insurance pool
- **Policy Management**: Users can purchase insurance policies with customizable coverage amounts
- **Claim Processing**: Policyholders can submit claims against their active policies
- **Democratic Voting**: Pool members vote on claim validity based on their contribution weight
- **Automated Execution**: Approved claims are automatically executed with built-in checks

## Contract Actions
The contract exposes a single public function `poolAction` that handles all operations:

1. **Contribute**
   - Action: `"contribute"`
   - Add funds to the insurance pool
   - Requires positive amount

2. **Purchase Policy**
   - Action: `"buy-policy"`
   - Purchase insurance coverage
   - Requires premium and coverage amount

3. **Submit Claim**
   - Action: `"submit-claim"`
   - File a claim against an active policy
   - Requires policy ID and description

4. **Vote on Claim**
   - Action: `"vote-claim"`
   - Cast weighted vote on pending claims
   - Requires claim ID and support boolean

5. **Execute Claim**
   - Action: `"execute-claim"`
   - Process approved claims
   - Requires claim ID

## Error Codes
- `ERR-NOT-POLICYHOLDER (u100)`: User is not the policyholder
- `ERR-ALREADY-CLAIMED (u101)`: Claim already processed
- `ERR-INSUFFICIENT-POOL (u102)`: Insufficient funds in pool
- `ERR-NOT-MEMBER (u103)`: User is not a pool member
- `ERR-ALREADY-VOTED (u104)`: Member already voted
- `ERR-NO-CLAIM (u105)`: Claim does not exist
- `ERR-INVALID-ACTION (u106)`: Invalid action requested
- `ERR-ZERO-AMOUNT (u107)`: Amount must be greater than zero

## Events
The contract emits events for:
- Contributions
- Policy purchases
- Claim submissions
- Voting activities
- Claim executions

[Add your license information here]
