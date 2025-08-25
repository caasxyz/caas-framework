module caas_framework::identity {
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::smart_table::{Self, SmartTable};
    use std::signer;
    use std::vector;
    use std::string::{String};
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // Identity Registry
    struct IdentityRegistry has key {
        // TypeInfo -> IdentityInfo
        registered_identities: SmartTable<TypeInfo, IdentityInfo>,
        // Project address -> TypeInfo list
        project_types: SmartTable<address, vector<TypeInfo>>
    }

    // Identity Information
    struct IdentityInfo has store, copy, drop {
        project_address: address,
        registered_at: u64,
        is_active: bool,
        api_key: String
    }

    #[event]
    struct WitnessDropEvent<phantom T> has copy, drop, store {
        api_key: String
    }

    #[event]
    struct IdentityRegisteredEvent<phantom T> has copy, store, drop {
        project_address: address,
        api_key: String
    }

    #[event]
    struct IdentityStatusToggledEvent<phantom T> has copy, store, drop {
        project_address: address,
        api_key: String,
        status_before_toggled: bool,
        status_after_toggled: bool
    }

    // Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_NOT_REGISTERED: u64 = 2;
    const E_REGISTERED: u64 = 3;
    const E_IDENTITY_DISABLED: u64 = 4;
    const E_INVALID_API_KEY: u64 = 5;

    fun init_module(sender: &signer) {
        move_to(
            sender,
            IdentityRegistry {
                registered_identities: smart_table::new<TypeInfo, IdentityInfo>(),
                project_types: smart_table::new<address, vector<TypeInfo>>()
            }
        )
    }

    // Register project identity (admin only)
    // Note: T does not require any ability constraints, only type info is fetched
    public fun register_identity<T: drop>(admin: &signer, api_key: String) acquires IdentityRegistry {
        // TODO: admin account management
        assert!(signer::address_of(admin) == @caas_admin, E_NOT_ADMIN);

        let type_info = type_info::type_of<T>();
        let project_addr = type_info::account_address(&type_info);

        let identity_info = IdentityInfo {
            project_address: project_addr,
            registered_at: timestamp::now_seconds(),
            is_active: true,
            api_key: api_key
        };
        event::emit(IdentityRegisteredEvent<T>{api_key, project_address: identity_info.project_address});

        // Update registry
        let registry = borrow_global_mut<IdentityRegistry>(@caas_framework);
        assert!(!registry.registered_identities.contains(type_info), E_REGISTERED);
        smart_table::add(&mut registry.registered_identities, type_info, identity_info);


        // Update project type mapping
        if (!smart_table::contains(&registry.project_types, project_addr)) {
            smart_table::add(&mut registry.project_types, project_addr, vector::empty());
        };
        let types = smart_table::borrow_mut(&mut registry.project_types, project_addr);
        vector::push_back(types, type_info);

        event::emit(WitnessDropEvent<T>{api_key});
    }

    // Verify project identity
    // Note: This function verifies identity, then drop witness
    public fun verify_identity<T: drop>(_witness: T): (bool, address) acquires IdentityRegistry {
        // Get type info of witness (includes its defining address)
        let type_info = type_info::type_of<T>();
        // type_info includes: address, module name, struct name
        // e.g.: 0x123::identity::ProjectIdentity

        let registry = borrow_global<IdentityRegistry>(@caas_framework);

        // Check if this type is registered
        assert!(
            smart_table::contains(&registry.registered_identities, type_info),
            E_NOT_REGISTERED
        );

        let identity_info = smart_table::borrow(&registry.registered_identities, type_info);
        assert!(identity_info.is_active, E_IDENTITY_DISABLED);

        event::emit(WitnessDropEvent<T>{api_key: identity_info.api_key});

        // Return project address
        (true, identity_info.project_address)
    }

    // Enable/disable project identity
    public fun toggle_identity_status<T>(admin: &signer, enabled: bool) acquires IdentityRegistry {
        assert!(signer::address_of(admin) == @caas_admin, E_NOT_ADMIN);

        let type_info = type_info::type_of<T>();
        let registry = borrow_global_mut<IdentityRegistry>(@caas_framework);

        let identity_info =
            smart_table::borrow_mut(&mut registry.registered_identities, type_info);
        let status_before_toggled = identity_info.is_active;
        identity_info.is_active = enabled;

        event::emit(IdentityStatusToggledEvent<T>{
            project_address: identity_info.project_address,
            api_key: identity_info.api_key,
            status_before_toggled,
            status_after_toggled: identity_info.is_active
        });
    }
}

