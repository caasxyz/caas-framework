module caas_framework::authorization {

    use std::signer;
    use std::string::{String};
    use aptos_std::smart_table::{Self, SmartTable};
    use caas_framework::identity;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    /// Project information
    struct AuthorizationKey has store, copy, drop {
        /// Project identifier
        // project_name: String,
        /// Project object address
        authorized_object_address: address,
        authorizer_object_address: address
        /// Authorizer address
        // authorizer: address
    }

    /// Project information
    /// Inter-project authorization registry
    struct AuthorizationRegistry has key {
        /// Authorized address -> Authorization information
        /// One authorized address can only correspond to one authorization relationship
        authorizations: SmartTable<AuthorizationKey, AuthorizationInfo>,

        /// Authorized party -> List of authorizers (for easy query)
        authorized_to_authorizers: SmartTable<address, vector<AuthorizationInfo>>,

        /// Authorizers party -> List of authorized (for easy query)
        authorizer_to_authorized_projects: SmartTable<address, vector<AuthorizationInfo>>
    }

    /// Project configuration (stored under the project object address)
    struct ProjectConfig has key {
        /// Project owner address
        owner: address,
        /// Project creation time
        created_at: u64
        /// Other project configurations...
    }

    /// Authorization details
    struct AuthorizationInfo has store, copy, drop {
        /// Project information
        project: address,

        /// Authorized party address
        /// TODO: may be distinguish from package even module
        authorized: address,

        /// Authorization creation time
        created_at: u64,

        /// Expiration time (0 means never expires)
        expires_at: u64,

        /// Whether enabled
        is_active: bool,

        /// Read permission
        read: bool,

        /// Write permission (temporarily not enabled, always false)
        write: bool
    }
    #[event]
    struct AuthorizationRevokedEvent has drop, copy, store {
        authorizer: address,
        authorized: address,
        timestamp: u64
    }

    #[event]
    struct AuthorizationUsedEvent has drop, copy, store {
        authorized: address,
        authorizer: address,
        timestamp: u64
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
                /// Authorizer address -> Authorization information
                /// One authorized address can only correspond to one authorization relationship
                authorizations: smart_table::new<AuthorizationKey, AuthorizationInfo>(),

                /// Authorized party -> List of authorizers (for easy query)
                authorized_to_authorizers: smart_table::new<address, vector<
                    AuthorizationInfo>>(),

                /// Authorized project -> Set of projects with permission
                authorizer_to_authorized_projects: smart_table::new<address, vector<
                    AuthorizationInfo>>()

            }
        )
    }

    public fun grant_read_authorization<T: drop>(
        witness: T,
        authorizer_address: address, // 授权方地址
        project_object_address: address, // 项目对象地址
        authorized_address: address, // 被授权方地址
        duration_seconds: u64 // 0 表示永久授权
    ) acquires AuthorizationRegistry {
        let (pass, witness_project_address) = identity::verify_identity(witness);
        assert!(pass, ENOT_VALID_WITNESS);
        assert!(
            authorizer_address == witness_project_address, EWITNESS_NOT_MATCH_PROJECT
        );
        // 验证不能自己授权给自己
        assert!(authorizer_address != authorized_address, E_CANNOT_AUTHORIZE_SELF);

        // 创建项目信息
        let authorization_key = AuthorizationKey {
            authorized_object_address: project_object_address,
            authorizer_object_address: authorizer_address
        };

        // 创建授权信息
        let auth_info = AuthorizationInfo {
            project: authorizer_address,
            authorized: authorized_address,
            created_at: timestamp::now_seconds(),
            expires_at: if (duration_seconds > 0) {
                timestamp::now_seconds() + duration_seconds
            } else { 0 },
            is_active: true,
            read: true,
            write: false // 写权限暂时不启用
        };

        // 更新注册表

        let registry = borrow_global_mut<AuthorizationRegistry>(@caas_framework);

        assert!(
            !registry.authorizations.contains(authorization_key), EALREADY_AUTHORIZED
        );

        // 使用被授权方地址作为 key
        add_authorizations(&mut registry.authorizations, authorization_key, auth_info);

        add_info(
            &mut registry.authorized_to_authorizers, project_object_address, auth_info
        );

        add_info(
            &mut registry.authorizer_to_authorized_projects,
            authorizer_address,
            auth_info
        );

        //TODO: emit a event
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

    /// 撤销授权（授权方可调用）
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

        // 检查授权是否存在
        assert!(
            smart_table::contains(&registry.authorizations, authorization_key),
            E_AUTHORIZATION_NOT_FOUND
        );

        let auth_info = smart_table::borrow(&registry.authorizations, authorization_key);

        // 移除授权
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

        // 发出撤销事件
        event::emit(
            AuthorizationRevokedEvent {
                authorizer: witness_project_address,
                authorized: authorized_address,
                timestamp: timestamp::now_seconds()
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

    /// 管理员禁用/启用授权
    public fun toggle_authorization(
        caas_admin: &signer,
        authorizer: address,
        authorized_address: address,
        is_active: bool
    ) acquires AuthorizationRegistry {
        // 验证调用者是 CaaS 管理员
        assert!(signer::address_of(caas_admin) == @caas_admin, E_NOT_ADMIN);

        let registry = borrow_global_mut<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey { 
            authorized_object_address: authorized_address, 
            authorizer_object_address: authorizer 
        };

        // 检查授权是否存在
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

        auth_info.is_active = is_active;

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

    /// 验证项目 B 是否有权读取项目 A 的数据
    public fun verify_read_authorization<T: drop>(
        witness: T, authorizer_address: address
    ): bool acquires AuthorizationRegistry {
        let (pass, witness_project_address) = identity::verify_identity<T>(witness);
        let registry = borrow_global<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey {
            authorized_object_address: witness_project_address,
            authorizer_object_address: authorizer_address
        };

        // 使用被授权方地址查找授权信息
        if (!smart_table::contains(&registry.authorizations, authorization_key)) {
            return false
        };

        let auth_info = smart_table::borrow(&registry.authorizations, authorization_key);

        // 验证所有项目信息是否匹配
        if (auth_info.project != authorizer_address) {
            return false
        };

        // 检查是否启用
        if (!auth_info.is_active) {
            return false
        };

        // 检查是否过期
        if (auth_info.expires_at > 0 && timestamp::now_seconds() > auth_info.expires_at) {
            return false
        };

        // 检查读权限
        auth_info.read
    }

    /// 通过项目对象地址验证授权
    public fun verify_read_authorization_by_project(
        authorized_address: address, project_object_address: address
    ): bool acquires AuthorizationRegistry {
        let registry = borrow_global<AuthorizationRegistry>(@caas_framework);

        let authorization_key = AuthorizationKey {
            authorized_object_address: authorized_address,
            authorizer_object_address: project_object_address
        };
        // 使用被授权方地址查找授权信息
        if (!smart_table::contains(&registry.authorizations, authorization_key)) {
            return false
        };

        let auth_info = smart_table::borrow(&registry.authorizations, authorization_key);

        // 检查是否启用
        if (!auth_info.is_active) {
            return false
        };

        // 检查是否过期
        if (auth_info.expires_at > 0 && timestamp::now_seconds() > auth_info.expires_at) {
            return false
        };

        // 检查读权限
        auth_info.read
    }

    /// 使用授权读取数据
    public fun use_authorization<T: drop>(
        authorizer_address: address, // 授权方地址
        witness: T // 被授权方的身份凭证
    ): bool acquires AuthorizationRegistry {
        // 验证被授权方身份
        let (pass, witness_project_address) =
            identity::verify_identity(witness);

        // 验证授权（现在需要完整的项目信息）
        assert!(
            verify_read_authorization(witness_project_address, authorizer_address),
            E_UNAUTHORIZED
        );

        // 发出事件
        event::emit(
            AuthorizationUsedEvent {
                authorized: witness_project_address,
                authorizer: authorizer_address,
                timestamp: timestamp::now_seconds()
            }
        );

        true
    }
}

