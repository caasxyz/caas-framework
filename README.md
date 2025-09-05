# CaaS Framework (Contract-as-a-Service)

A powerful Aptos blockchain framework that enables secure cross-contract communication, decentralized identity management, and hierarchical data storage for Web3 applications.

## 🎯 Overview

CaaS Framework is a production-ready infrastructure layer for Aptos dApps that solves critical challenges in smart contract development:

- **Identity Management**: Register and verify project identities without central authorities
- **Cross-Contract Authorization**: Securely grant and manage permissions between different contracts
- **Hierarchical Data Storage**: Organize and share data across contracts using namespace trees

Built with Move's type safety and witness pattern, CaaS ensures secure, gas-efficient operations while maintaining full decentralization.

## 🏗️ Architecture

### Core Modules

#### 🔐 **Identity Module** (`caas_framework::identity`)
Manages project identities and verification across the ecosystem.

| Feature | Description |
|---------|------------|
| **Registration** | Admin-controlled project identity creation with API key support |
| **Witness Pattern** | Type-safe verification using Move's witness system |
| **Project Mapping** | Automatic address-to-identity resolution |
| **Toggle Control** | Enable/disable identities without deletion |

#### 🔑 **Authorization Module** (`caas_framework::authorization`)
Handles fine-grained permission management between contracts.

| Feature | Description |
|---------|------------|
| **Permission Types** | Support for read/write access levels |
| **Time-based Expiry** | Automatic permission expiration after specified duration |
| **Revocation** | Immediate permission withdrawal capability |
| **Event Tracking** | Complete audit trail of all authorization changes |

#### 📁 **Namespace Module** (`caas_framework::namespace`)
Provides hierarchical data organization and sharing.

| Feature | Description |
|---------|------------|
| **Tree Structure** | Parent-child namespace relationships |
| **Object Storage** | Each namespace as an extensible Aptos object |
| **Access Control** | Authorization-based cross-contract data access |
| **Type Safety** | Generic data containers with compile-time verification |

## ✨ Key Features

- ⚡ **Zero Central Authority** - Fully decentralized identity and permission management
- 🔒 **Type-Safe Operations** - Compile-time verification using Move's type system
- ⏱️ **Automatic Expiration** - Time-based permissions with no manual cleanup needed
- 🌳 **Hierarchical Organization** - Intuitive parent-child namespace relationships
- 📊 **Complete Auditability** - Event emission for all critical operations
- 🔧 **Extensible Architecture** - Add custom resources to namespace objects
- 🚀 **Gas Optimized** - Efficient storage patterns and minimal transaction overhead

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

## 🚀 Getting Started

### Prerequisites

- [Aptos CLI](https://aptos.dev/tools/install-cli/) (v3.0+)
- Move development environment
- Active Aptos account with gas tokens

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd caas
```

2. **Build the framework**
```bash
cd CaasFramework
aptos move compile
```

3. **Run tests** (optional but recommended)
```bash
aptos move test
```

4. **Deploy to network**
```bash
# Testnet deployment
aptos move publish --profile testnet

# Mainnet deployment  
aptos move publish --profile mainnet
```

## 📖 Usage Examples

### Step 1: Register Your Project Identity

First, register your project with the CaaS framework:

```move
module my_project::setup {
    use caas_framework::identity;
    
    struct MyProjectWitness has drop {}
    
    public entry fun register_my_project(admin: &signer, api_key: String) {
        identity::register_identity<MyProjectWitness>(admin, api_key);
    }
}
```

### Step 2: Grant Cross-Contract Permissions

Enable other contracts to access your data:

```move
module my_project::permissions {
    use caas_framework::authorization;
    
    public entry fun allow_partner_access(
        witness: MyProjectWitness,
        my_address: address,
        partner_address: address,
        duration_seconds: u64
    ) {
        authorization::grant_read_authorization(
            witness,
            my_address,
            partner_address,
            partner_address,
            duration_seconds
        );
    }
}
```

### Step 3: Create and Manage Namespaces

Organize your data hierarchically:

```move
module my_project::storage {
    use caas_framework::namespace;
    use std::option;
    
    struct MyData has store {
        value: u64,
        metadata: String
    }
    
    public entry fun setup_storage(witness: MyProjectWitness) {
        // Create root namespace
        let root = namespace::create_namespace(witness, option::none());
        
        // Create child namespace
        let child = namespace::create_namespace(witness, option::some(root));
        
        // Store data
        let data = MyData { value: 100, metadata: b"example" };
        namespace::patch_data(child, data, witness);
    }
}

## 💡 Real-World Example: Label System

The included `label` module showcases a production use case - a decentralized user labeling system:

```move
// Add a label to a user
label::add_label(user_address, b"premium_user", witness);

// Query user labels from another contract (with authorization)
let labels = label::get_user_labels(user_address, authorized_witness);
```

**Key Implementation Patterns:**
- ✅ Witness-based authentication for all operations
- ✅ Namespace-backed persistent storage
- ✅ Cross-contract data sharing via authorization
- ✅ Event emission for off-chain indexing

## 📚 API Reference

### Identity Module

| Function | Description | Parameters |
|----------|-------------|------------|
| `register_identity<T>` | Register a new project identity | `admin: &signer`<br>`api_key: String` |
| `verify_identity<T>` | Verify and consume witness | `witness: T` |
| `toggle_identity<T>` | Enable/disable identity | `admin: &signer`<br>`enabled: bool` |
| `is_identity_enabled<T>` | Check identity status | Returns: `bool` |

### Authorization Module

| Function | Description | Parameters |
|----------|-------------|------------|
| `grant_read_authorization<T>` | Grant read permission | `witness: T`<br>`authorizer: address`<br>`authorized: address`<br>`duration: u64` |
| `grant_write_authorization<T>` | Grant write permission | Same as read |
| `revoke_authorization<T>` | Revoke permission | `witness: T`<br>`authorized: address` |
| `verify_read_authorization<T>` | Check read permission | `witness: T`<br>`authorizer: address` |

### Namespace Module

| Function | Description | Parameters |
|----------|-------------|------------|
| `create_namespace<T>` | Create new namespace | `witness: T`<br>`parent: Option<Object>` |
| `patch_data<T, Data>` | Store/update data | `namespace: Object`<br>`data: Data`<br>`witness: T` |
| `get_data_by_witness<T, Data>` | Retrieve with witness | `namespace: Object`<br>`witness: T` |
| `get_data_by_authorization<Data>` | Retrieve with auth | `namespace: Object`<br>`authorizer: address` |

## 🛡️ Security Considerations

### Best Practices
- 🔐 **Admin Key Security**: Store admin keys in hardware wallets or secure key management systems
- ⏰ **Permission Duration**: Set reasonable expiration times (recommended: 24-72 hours for temporary access)
- 🔍 **Witness Validation**: Always verify witness types match expected project identities
- 📝 **Event Monitoring**: Implement off-chain monitoring for authorization events
- 🚫 **Revocation Strategy**: Maintain ability to quickly revoke compromised permissions

### Security Features
- ✅ Signer verification for all administrative functions
- ✅ Type-safe witness pattern prevents identity spoofing
- ✅ Automatic permission expiration reduces attack surface
- ✅ Immutable audit trail via blockchain events
- ✅ No upgradeable contracts - code is law

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass (`aptos move test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines
- Follow Move best practices and naming conventions
- Add comprehensive tests for new features
- Update documentation for API changes
- Include event emissions for important state changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💬 Support & Community

- 📧 **Issues**: [GitHub Issues](https://github.com/your-org/caas/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-org/caas/discussions)
- 📚 **Documentation**: [Wiki](https://github.com/your-org/caas/wiki)

---

Built with ❤️ for the Aptos ecosystem