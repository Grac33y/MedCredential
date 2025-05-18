# MedCredential

MedCredential is a decentralized healthcare credential verification platform built on Clarity smart contracts where provider credentials are verified on-chain and providers earn tokens based on consultations and patient satisfaction ratings.

## Overview

This smart contract enables a healthcare credential verification platform with the following features:

- **Credential Submission**: Providers can submit credentials with cryptographic hashing for integrity
- **On-chain Verification**: Other providers verify credential authenticity
- **Consultation Tracking**: System tracks patient consultations with verified providers
- **Satisfaction Ratings**: Patients rate provider satisfaction on a scale of 1-5
- **Token Rewards**: Providers earn tokens based on consultations and satisfaction ratings
- **Reputation System**: Providers build reputation through positive contributions

## Contract Functions

### Provider Management
- `register-provider`: Register as a new provider with name and specialty
- `update-provider-info`: Update your provider information
- `get-provider-info`: Get information about a provider

### Credential Management
- `submit-credential`: Submit a new credential with description and credential hash
- `get-credential`: Get information about a credential
- `get-total-credentials`: Get the total number of credentials on the platform

### Verification System
- `verify-credential`: Verify the authenticity of a credential
- `get-credential-verification`: Check if a provider has verified a credential

### Consultation System
- `record-consultation`: Record a patient consultation with notes
- `get-consultation`: Check a patient's consultation record

### Rating System
- `rate-provider-satisfaction`: Rate provider satisfaction (1-5)
- `get-patient-rating`: Get a patient's rating for a provider

## Reward Mechanisms

The contract includes several token reward mechanisms:

1. **Verification Rewards**:
   - Providers who verify credentials receive 5 tokens and 1 reputation point
   - Credential owners receive 50 tokens and 10 reputation points when their credential is verified by 3+ providers

2. **Consultation Rewards**:
   - Providers receive 10 tokens for each patient consultation

3. **Satisfaction Rewards**:
   - Providers receive 20 tokens and 5 reputation points for high satisfaction ratings (4-5 stars)

## Development

This contract is designed to be deployed on the Stacks blockchain and can be tested using Clarinet.