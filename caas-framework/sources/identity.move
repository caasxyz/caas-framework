module caas_framework::identity {
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::smart_table::{Self, SmartTable};
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // Identity Registry
    struct IdentityRegistry has key {
        // TypeInfo -> IdentityInfo
        registered_identities: SmartTable<TypeInfo, IdentityInfo>,
        // API key -> IdentityInfo
        registered_identity_string: SmartTable<String, TypeInfo>,
        // Project address -> TypeInfo list
        project_types: SmartTable<address, vector<TypeInfo>>
    }

    // Identity Information
    struct IdentityInfo has store, copy, drop {
        project_address: address,
        module_name: String,
        struct_name: String,
        registered_at: u64,
        is_active: bool,
        identity: String,
    }

    #[event]
    struct WitnessDropEvent<phantom T> has copy, drop, store {
        identity: String
    }

    #[event]
    struct IdentityRegisteredEvent<phantom T> has copy, store, drop {
        project_address: address,
        identity: String
    }

    #[event]
    struct IdentityStatusToggledEvent<phantom T> has copy, store, drop {
        project_address: address,
        identity: String,
        status_before_toggled: bool,
        status_after_toggled: bool
    }

    // Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_NOT_REGISTERED: u64 = 2;
    const E_REGISTERED: u64 = 3;
    const E_IDENTITY_DISABLED: u64 = 4;
    const EPROJECT_ADDRESS_NOT_MATCH: u64 = 5;
    const EMODULE_NAME_NOT_MATCH: u64 = 6;
    const ESTRUCT_NAME_NOT_MATCH: u64 = 7;

    fun init_module(sender: &signer) {
        move_to(
            sender,
            IdentityRegistry {
                registered_identities: smart_table::new<TypeInfo, IdentityInfo>(),
                registered_identity_string: smart_table::new<String, TypeInfo>(),
                project_types: smart_table::new<address, vector<TypeInfo>>()
            }
        )
    }

    // Register project identity (admin only)
    // Note: T does not require any ability constraints, only type info is fetched
    public entry fun register_identity<T: drop>(admin: &signer, identity: String) acquires IdentityRegistry {
        // TODO: admin account management
        assert!(signer::address_of(admin) == @caas_admin, E_NOT_ADMIN);
        register_identity_internal<T>(identity);
    }

    fun register_identity_internal<T: drop>(identity: String) acquires IdentityRegistry {

        let type_info = type_info::type_of<T>();
        let project_addr = type_info::account_address(&type_info);
        let module_name = string::utf8(type_info::module_name(&type_info));
        let struct_name = string::utf8(type_info::struct_name(&type_info));

        let identity_info = IdentityInfo {
            project_address: project_addr,
            module_name,
            struct_name,
            registered_at: timestamp::now_seconds(),
            is_active: true,
            identity: identity,
        };
        event::emit(IdentityRegisteredEvent<T>{identity, project_address: identity_info.project_address});

        // Update registry
        let registry = borrow_global_mut<IdentityRegistry>(@caas_framework);
        assert!(!registry.registered_identities.contains(type_info), E_REGISTERED);
        assert!(!registry.registered_identity_string.contains(identity), E_REGISTERED);
        smart_table::add(&mut registry.registered_identities, type_info, identity_info);
        smart_table::add(&mut registry.registered_identity_string, identity, type_info);

        // Update project type mapping
        if (!smart_table::contains(&registry.project_types, project_addr)) {
            smart_table::add(&mut registry.project_types, project_addr, vector::empty());
        };
        let types = smart_table::borrow_mut(&mut registry.project_types, project_addr);
        vector::push_back(types, type_info);

        event::emit(WitnessDropEvent<T>{identity});

    }

    // Verify project identity
    // Note: This function verifies identity, then drop witness
    public fun verify_identity<T: drop>(_witness: T): (bool, address) acquires IdentityRegistry {
        let witness_type_info = get_witness_type_info<T>();
        let (project_address, module_name, struct_name) = get_witness_type_info_detail<T>(&witness_type_info); 

        let registry = borrow_global<IdentityRegistry>(@caas_framework);

        assert_witness_is_registered(registry, witness_type_info);

        let identity_info = smart_table::borrow(&registry.registered_identities, witness_type_info);
        assert_identity_is_valid(identity_info, project_address, module_name, struct_name);

        event::emit(WitnessDropEvent<T>{identity: identity_info.identity});

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
            identity: identity_info.identity,
            status_before_toggled,
            status_after_toggled: identity_info.is_active
        });
    }

    public fun get_project_address_by_type<T: drop>(): address {
        let witness_type_info = type_info::type_of<T>();
        type_info::account_address(&witness_type_info)
    }

    fun assert_identity_is_valid(
        identity_info: &IdentityInfo, 
        project_address: address, 
        module_name: vector<u8>, 
        struct_name: vector<u8>
    ) {
        assert!(identity_info.project_address == project_address, EPROJECT_ADDRESS_NOT_MATCH);
        assert!(identity_info.module_name == string::utf8(module_name), EMODULE_NAME_NOT_MATCH);
        assert!(identity_info.struct_name == string::utf8(struct_name), ESTRUCT_NAME_NOT_MATCH);
        assert!(identity_info.is_active, E_IDENTITY_DISABLED);

    }

    fun assert_witness_is_registered(registry: &IdentityRegistry, witness_type_info: TypeInfo) {
        // Check if this type is registered
        assert!(
            smart_table::contains(&registry.registered_identities, witness_type_info),
            E_NOT_REGISTERED
        );
    }

    // Get type info of witness (includes its defining address)
    fun get_witness_type_info<T: drop>(): TypeInfo {
        type_info::type_of<T>()
    }

    fun get_witness_type_info_detail<T: drop>(witness_type_info: &TypeInfo): (address, vector<u8>, vector<u8>) {
        // type_info includes: address, module name, struct name
        // e.g.: 0x123::identity::ProjectIdentity
        let project_address = type_info::account_address(witness_type_info);
        let module_name = type_info::module_name(witness_type_info);
        let struct_name = type_info::struct_name(witness_type_info);

        (project_address, module_name, struct_name)

    }
}

