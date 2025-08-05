module caas::identity_verification {
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::table::{Self, Table};
    use std::hash;
    use std::vector;
    use std::string::{String};

    /// Identity Registry
    struct IdentityRegistry has key {
        /// TypeInfo -> IdentityInfo
        registered_identities: Table<TypeInfo, IdentityInfo>,
        /// Project address -> TypeInfo list
        project_types: Table<address, vector<TypeInfo>>
    }

    /// Identity Information
    struct IdentityInfo has store, copy, drop {
        project_address: address,
        registered_at: u64,
        is_active: bool,
        api_key: String
    }

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_NOT_REGISTERED: u64 = 2;
    const E_IDENTITY_DISABLED: u64 = 3;
    const E_INVALID_API_KEY: u64 = 4;

    /// Register project identity (admin only)
    /// Note: T does not require any ability constraints, only type info is fetched
    public fun register_identity<T>(admin: &signer, api_key: String) acquires IdentityRegistry {
        assert!(signer::address_of(admin) == @caas_admin, E_NOT_ADMIN);

        let type_info = type_info::type_of<T>();
        let project_addr = type_info::account_address(&type_info);

        let identity_info = IdentityInfo {
            project_address: project_addr,
            registered_at: timestamp::now_seconds(),
            is_active: true,
            api_key: api_key
        };

        // Update registry
        let registry = borrow_global_mut<IdentityRegistry>(@caas);
        table::add(&mut registry.registered_identities, type_info, identity_info);

        // Update project type mapping
        if (!table::contains(&registry.project_types, project_addr)) {
            table::add(&mut registry.project_types, project_addr, vector::empty());
        };
        let types = table::borrow_mut(&mut registry.project_types, project_addr);
        vector::push_back(types, type_info);
    }

    /// Verify project identity
    /// Note: This function only verifies identity, does not consume witness
    public fun verify_identity<T: drop>(witness: T): (bool, address) acquires IdentityRegistry {
        // Get type info of witness (includes its defining address)
        let type_info = type_info::type_of<T>();
        // type_info includes: address, module name, struct name
        // e.g.: 0x123::identity::ProjectIdentity

        let registry = borrow_global<IdentityRegistry>(@caas);

        // Check if this type is registered
        assert!(
            table::contains(&registry.registered_identities, type_info),
            E_NOT_REGISTERED
        );

        let identity_info = table::borrow(&registry.registered_identities, type_info);
        assert!(identity_info.is_active, E_IDENTITY_DISABLED);

        // Return project address
        (true, identity_info.project_address)
    }

    /// Enable/disable project identity
    public fun toggle_identity_status<T>(admin: &signer, enabled: bool) acquires IdentityRegistry {
        assert!(signer::address_of(admin) == @caas_admin, E_NOT_ADMIN);

        let type_info = type_info::type_of<T>();
        let registry = borrow_global_mut<IdentityRegistry>(@caas);

        let identity_info =
            table::borrow_mut(&mut registry.registered_identities, type_info);
        identity_info.is_active = enabled;
    }
}

