# CaaS Framework (Contract-as-a-Service)

A comprehensive blockchain-based framework built on Aptos for managing smart contract services with identity verification, authorization, and namespace management.

## Overview

CaaS Framework provides a decentralized infrastructure for managing project identities, cross-project authorizations, and data namespaces on the Aptos blockchain. It enables secure inter-contract communication and resource sharing through a robust permission system.

## Architecture

The framework consists of three core modules:

### 🔐 Identity Module (`caas_framework::identity`)
- **Project Identity Registration**: Admin-managed registration system for project identities
- **Witness-based Verification**: Type-safe identity verification using Move's witness pattern
- **Project Mapping**: Links project addresses to their registered identity types

### 🔑 Authorization Module (`caas_framework::authorization`) 
- **Cross-contract Permissions**: Grant read/write access between different contracts
- **Time-based Expiration**: Configurable authorization duration with automatic expiry
- **Revocation System**: Ability to revoke granted permissions
- **Event Logging**: Track authorization usage and revocations

### 📁 Namespace Module (`caas_framework::namespace`)
- **Hierarchical Storage**: Create parent-child namespace relationships
- **Object-based Architecture**: Each namespace is an Aptos object with extensible resources
- **Access Control**: Integration with authorization system for cross-contract data access
- **Data Containers**: Type-safe storage and retrieval of arbitrary data types

## Key Features

- **Decentralized Identity Management**: No central authority required for project operations
- **Fine-grained Permissions**: Control read/write access at the contract level
- **Type Safety**: Leverage Move's type system for secure operations
- **Extensible Design**: Namespace objects can be extended with additional resources
- **Event Tracking**: Comprehensive logging of all system interactions

## Project Structure

```
caas/
├── CaasFramework/          # Core framework modules
│   ├── sources/
│   │   ├── authorization.move  # Inter-project authorization system
│   │   ├── identity.move      # Project identity management
│   │   └── namespace.move     # Hierarchical data storage
│   └── Move.toml
└── label/                  # Example use case implementation
    ├── sources/
    │   └── label.move         # User labeling system using CaaS
    └── Move.toml
```

## Getting Started

### Prerequisites
- [Aptos CLI](https://aptos.dev/tools/install-cli/)
- Move development environment

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd caas
```

2. Build the framework:
```bash
cd CaasFramework
aptos move compile
```

3. Deploy to your preferred network:
```bash
aptos move publish --profile <your-profile>
```

### Basic Usage

#### 1. Register a Project Identity

```move
// Admin registers a new project identity
public fun register_project<ProjectWitness: drop>(admin: &signer, api_key: String) {
    caas_framework::identity::register_identity<ProjectWitness>(admin, api_key);
}
```

#### 2. Grant Authorization Between Projects

```move
// Project A grants read access to Project B
public fun grant_access<ProjectAWitness: drop>(
    witness: ProjectAWitness,
    project_a_address: address,
    project_b_address: address,
    duration: u64
) {
    caas_framework::authorization::grant_read_authorization(
        witness,
        project_a_address,
        project_b_address,
        project_b_address,
        duration
    );
}
```

#### 3. Create and Use Namespaces

```move
// Create a namespace for data storage
public fun create_data_namespace<ProjectWitness: drop>(witness: ProjectWitness) {
    let namespace = caas_framework::namespace::create_namespace(witness, option::none());
    // Store data in the namespace
    caas_framework::namespace::patch_data(namespace, my_data, witness);
}
```

## Use Case Example: Label System

The `label` module demonstrates practical usage of the CaaS Framework:

- **Identity Integration**: Uses project witness for authentication
- **Namespace Storage**: Stores label data in dedicated namespaces  
- **Cross-contract Access**: Other contracts can read label data with proper authorization
- **Event Emission**: Tracks label additions and modifications

## API Reference

### Identity Module
- `register_identity<T: drop>(admin: &signer, api_key: String)`: Register a project identity
- `verify_identity<T: drop>(witness: T): (bool, address)`: Verify and consume a witness
- `toggle_identity<T>(admin: &signer, enabled: bool)`: Enable/disable an identity

### Authorization Module  
- `grant_read_authorization<T: drop>(...)`: Grant read permission between projects
- `revoke_authorization<T: drop>(witness: T, authorized: address)`: Revoke permission
- `verify_read_authorization<T: drop>(witness: T, authorizer: address): bool`: Check permission

### Namespace Module
- `create_namespace<T: drop>(witness: T, parent: Option<Object<NamespaceCore>>)`: Create namespace
- `patch_data<T: drop, DataType: store>(namespace: Object<NamespaceCore>, data: DataType, witness: T)`: Store data
- `get_data_by_witness<T: drop, DataType: store>(...): (DataType, Voucher<DataType>)`: Retrieve data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality  
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Security Considerations

- All administrative functions require proper signer verification
- Cross-contract access is strictly controlled through the authorization system
- Data access requires either ownership or explicit authorization
- Time-based permissions automatically expire for enhanced security

## Support

For questions and support, please open an issue in the repository.