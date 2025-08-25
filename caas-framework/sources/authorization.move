module caas_framework::authorization {

    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use caas_framework::identity;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // Project information
    struct AuthorizationKey has store, copy, drop {
        // Project identifier
        // project_name: String,
        // Project object address
        authorized_object_address: address,
        authorizer_object_address: address
        // Authorizer address
        // authorizer: address
    }

    // Project information
    // Inter-project authorization registry
    struct AuthorizationRegistry has key {
        // Authorized address -> Authorization information
        // One authorized address can only correspond to one authorization relationship
        authorizations: SmartTable<AuthorizationKey, AuthorizationInfo>,

        // Authorized party -> List of authorizers (for easy query)
        authorized_to_authorizers: SmartTable<address, vector<AuthorizationInfo>>,

        // Authorizers party -> List of authorized (for easy query)
        authorizer_to_authorized_projects: SmartTable<address, vector<AuthorizationInfo>>
    }

    // Project configuration (stored under the project object address)
    struct ProjectConfig has key {
        // Project owner address
        owner: address,
        // Project creation time
        created_at: u64
        // Other project configurations...
    }

    // Authorization details
    struct AuthorizationInfo has store, copy, drop {
        // Project information
        project: address,

        // Authorized party address
        // TODO: may be distinguish from package even module
        authorized: address,

        // Authorization creation time
        created_at: u64,

        // Expiration time (0 means never expires)
        expires_at: u64,

        // Whether enabled
        is_active: bool,

        // Read permission
        read: bool,

        // Write permission (temporarily not enabled, always false)
        write: bool
    }

    #[event]
    struct GrantReadAuthorizationEvent has drop, copy, store {
        authorizer: address,
        authorized: address
    }


    #[event]
    struct AuthorizationRevokedEvent has drop, copy, store {
        authorizer: address,
        authorized: address
    }

    #[event]
    struct AuthorizationUsedEvent has drop, copy, store {
        authorized: address,
        authorizer: address
    }

    #[event]
    struct AuthorizationToggledEvent has drop, copy, store {
        authorizer: address,
        authorized_address: address,
        toggle_status_before: bool,
        toggle_status_after: bool
    }

    const ENOT_VALID_WITNESS: u64 = 1;
    const EWITNESS_NOT_MATCH_PROJECT: u64 = 2;
    const E_CANNOT_AUTHORIZE_SELF: u64 = 3;
    const EALREADY_AUTHORIZED: u64 = 4;
    const E_AUTHORIZATION_NOT_FOUND: u64 = 5;
    const E_NOT_ADMIN: u64 = 6;
    const E_UNAUTHORIZED: u64 = 7;

    fun init_module(sender: &signer) {
        move_to(
            sender,
            AuthorizationRegistry {
                // Authorizer address -> Authorization information
                // One authorized address can only correspond to one authorization relationship
                authorizations: smart_table::new<AuthorizationKey, AuthorizationInfo>(),

                // Authorized party -> List of authorizers (for easy query)
                authorized_to_authorizers: smart_table::new<address, vector<
                    AuthorizationInfo>>(),

                // Authorized project -> Set of projects with permission
                authorizer_to_authorized_projects: smart_table::new<address, vector<
                    AuthorizationInfo>>()

            }
        )
    }

    public fun grant_read_authorization<T: drop>(
        witness: T,
        authorizer_address: address, // Authorizer address
        project_object_address: address, // Project object address
        authorized_address: address, // Authorized party address
        duration_seconds: u64 // 0 means permanent authorization
    ) acquires AuthorizationRegistry {
        let (pass, witness_project_address) = identity::verify_identity(witness);
        assert!(pass, ENOT_VALID_WITNESS);
        assert!(
            authorizer_address == witness_project_address, EWITNESS_NOT_MATCH_PROJECT
        );
        // Verify cannot authorize self
        assert!(authorizer_address != authorized_address, E_CANNOT_AUTHORIZE_SELF);

        // Create project information
        let authorization_key = AuthorizationKey {
            authorized_object_address: project_object_address,
            authorizer_object_address: authorizer_address
        };

        // Create authorization information
        let auth_info = AuthorizationInfo {
            project: authorizer_address,
            authorized: authorized_address,
            created_at: timestamp::now_seconds(),
            expires_at: if (duration_seconds > 0) {
                timestamp::now_seconds() + duration_seconds
            } else { 0 },
            is_active: true,
            read: true,
            write: false // Write permission temporarily disabled
        };

        // Update registry

        let registry = borrow_global_mut<AuthorizationRegistry>(@caas_framework);

        assert!(
            !registry.authorizations.contains(authorization_key), EALREADY_AUTHORIZED
        );

        // Use authorized party address as key
        add_authorizations(&mut registry.authorizations, authorization_key, auth_info);

        add_info(
            &mut registry.authorized_to_authorizers, project_object_address, auth_info
        );

        add_info(
            &mut registry.authorizer_to_authorized_projects,
            authorizer_address,
            auth_info
        );

        event::emit(
            GrantReadAuthorizationEvent {
                authorizer: authorizer_address,
                authorized: authorized_address
            }
        );
    }

    inline fun add_authorizations(
        authorizations: &mut SmartTable<AuthorizationKey, AuthorizationInfo>,
        authorization_key: AuthorizationKey,
        authorization_info: AuthorizationInfo
    ) {
        authorizations.add(authorization_key, authorization_info);
    }

    inline fun add_info(
        infos: &mut SmartTable<address, vector<AuthorizationInfo>>,
        key: address,
        authorization_info: AuthorizationInfo
    ) {
        if (infos.contains(key)) {
            let info_vec = infos.borrow_mut(key);
            info_vec.push_back(authorization_info);
        } else {
            infos.add(key, vector[authorization_info]);
        }
    }

    // Revoke authorization (callable by authorizer)
    public fun revoke_authorization<T: drop>(
        witness: T, authorized_address: address
    ) acquires AuthorizationRegistry {
        let (pass, witness_project_address) = identity::verify_identity(witness);
        assert!(pass, ENOT_VALID_WITNESS);

        let registry = borrow_global_mut<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey {
            authorized_object_address: authorized_address,
            authorizer_object_address: witness_project_address
        };

        // Check if authorization exists
        assert!(
            smart_table::contains(&registry.authorizations, authorization_key),
            E_AUTHORIZATION_NOT_FOUND
        );

        // Remove authorization
        let auth_info =
            smart_table::remove(&mut registry.authorizations, authorization_key);

        remove_info(
            &mut registry.authorized_to_authorizers, authorized_address, auth_info
        );

        remove_info(
            &mut registry.authorizer_to_authorized_projects,
            witness_project_address,
            auth_info
        );

        // Emit revocation event
        event::emit(
            AuthorizationRevokedEvent {
                authorizer: witness_project_address,
                authorized: authorized_address
            }
        );
    }

    inline fun remove_info(
        auth_infos: &mut SmartTable<address, vector<AuthorizationInfo>>,
        key: address,
        value: AuthorizationInfo
    ) {
        let info_list = auth_infos.borrow_mut(key);
        let (exi, index) = info_list.find(|e| { *e == value });
        if (exi) {
            info_list.remove(index);
        };
    }

    // Admin disable/enable authorization
    public fun toggle_authorization(
        caas_admin: &signer,
        authorizer: address,
        authorized_address: address,
        is_active: bool
    ) acquires AuthorizationRegistry {
        // Verify caller is CaaS admin
        assert!(signer::address_of(caas_admin) == @caas_admin, E_NOT_ADMIN);

        let registry = borrow_global_mut<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey { 
            authorized_object_address: authorized_address, 
            authorizer_object_address: authorizer 
        };

        // Check if authorization exists
        assert!(
            smart_table::contains(&registry.authorizations, authorization_key),
            E_AUTHORIZATION_NOT_FOUND
        );

        let auth_info =
            smart_table::borrow_mut(&mut registry.authorizations, authorization_key);

        set_auth_info_is_active(
            &mut registry.authorized_to_authorizers,
            authorized_address,
            *auth_info,
            is_active
        );
        set_auth_info_is_active(
            &mut registry.authorizer_to_authorized_projects,
            authorizer,
            *auth_info,
            is_active
        );

        let toggle_status_before = auth_info.is_active;
        let toggle_status_after = is_active;

        auth_info.is_active = is_active;

        event::emit(AuthorizationToggledEvent{
            authorizer,
            authorized_address,
            toggle_status_before,
            toggle_status_after
        });

    }

    inline fun set_auth_info_is_active(
        auth_infos: &mut SmartTable<address, vector<AuthorizationInfo>>,
        key: address,
        value: AuthorizationInfo,
        is_active: bool
    ) {
        let info_list = auth_infos.borrow_mut(key);
        let (exi, index) = info_list.find(|e| { *e == value });
        if (exi) {
            info_list[index].is_active = is_active;
        };

    }

    // Verify if project B has permission to read project A's data
    public fun verify_read_authorization<T: drop>(
        witness: T, authorizer_address: address
    ): bool acquires AuthorizationRegistry {
        let (_pass, witness_project_address) = identity::verify_identity<T>(witness);
        let registry = borrow_global<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey {
            authorized_object_address: witness_project_address,
            authorizer_object_address: authorizer_address
        };

        // Use authorized party address to find authorization info
        if (!smart_table::contains(&registry.authorizations, authorization_key)) {
            return false
        };

        let auth_info = smart_table::borrow(&registry.authorizations, authorization_key);

        // Verify all project information matches
        if (auth_info.project != authorizer_address) {
            return false
        };

        // Check if enabled
        if (!auth_info.is_active) {
            return false
        };

        // Check if expired
        if (auth_info.expires_at > 0 && timestamp::now_seconds() > auth_info.expires_at) {
            return false
        };

        // Check read permission
        auth_info.read
    }

    // Verify authorization through project object address
    public fun verify_read_authorization_by_project(
        authorized_address: address, project_object_address: address
    ): bool acquires AuthorizationRegistry {
        let registry = borrow_global<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey {
            authorized_object_address: authorized_address,
            authorizer_object_address: project_object_address
        };
        // Use authorized party address to find authorization info
        if (!smart_table::contains(&registry.authorizations, authorization_key)) {
            return false
        };

        let auth_info = smart_table::borrow(&registry.authorizations, authorization_key);

        // Check if enabled
        if (!auth_info.is_active) {
            return false
        };

        // Check if expired
        if (auth_info.expires_at > 0 && timestamp::now_seconds() > auth_info.expires_at) {
            return false
        };

        // Check read permission
        auth_info.read
    }

    // Use authorization to read data
    public fun use_authorization<T: drop>(
        authorizer_address: address, // Authorizer address
        witness: T // Authorized party's identity credential
    ): bool acquires AuthorizationRegistry {
        // Verify authorized party identity
        let (_pass, witness_project_address) =
            identity::verify_identity(witness);

        // Verify authorization (now requires complete project information)
        assert!(
            verify_read_authorization(witness_project_address, authorizer_address),
            E_UNAUTHORIZED
        );

        // Emit event
        event::emit(
            AuthorizationUsedEvent {
                authorized: witness_project_address,
                authorizer: authorizer_address
            }
        );

        true
    }
}

