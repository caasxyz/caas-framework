module caas::namespace {

    use std::string::{String};
    use std::option::{Option};
    use aptos_std::smart_table::{SmartTable};

    /// Namespace registry (stored under @caas)
    struct NamespaceRegistry has key {
        /// Namespace full name → object address
        name_to_object: SmartTable<String, address>,

        /// Creator address → namespace list
        creator_to_namespaces: SmartTable<address, vector<address>>,

        /// Project address → namespace list (a project can have multiple namespaces)
        project_to_namespaces: SmartTable<address, vector<address>>,

        /// Creation time index (bucketed by day)
        creation_time_index: SmartTable<u64, vector<address>>,

        /// Statistics
        total_namespaces: u64,
        total_root_spaces: u64,
        total_sub_spaces: u64
    }

    /// Namespace object metadata (stored under each namespace object address)
    struct NamespaceCore has key {
        /// Namespace name (e.g., "uniswap" or "uniswap.v3")
        name: String,

        /// Creator's project address
        creator: address,

        /// Associated project info
        project_info: ProjectInfo,

        /// Parent namespace address (None for root namespace)
        parent: Option<address>,

        /// List of child namespaces
        children: vector<address>,

        /// Timestamps
        created_at: u64,
        updated_at: u64,

        /// Whether verified by CaaS
        is_verified: bool,

        /// Namespace attributes (key-value storage)
        attributes: SmartTable<String, String>,

        /// Access statistics
        access_count: u64,
        last_accessed: u64
    }

    /// Namespace configuration (controls access permissions and behavior)
    struct NamespaceConfig has key {
        /// Whether sub-namespaces can be created
        allow_subspaces: bool,

        /// Permission level for subspace creation
        subspace_creation_permission: u8,

        /// Whether ownership is transferable
        is_transferable: bool,

        /// Whether public (public namespaces can be read by anyone)
        is_public: bool,

        /// Whether sharing via authorization system is allowed
        allow_authorization: bool,

        /// Direct access control list (project addresses)
        access_control_list: vector<address>
    }

    /// Project information
    struct ProjectInfo has store, copy, drop {
        /// Project identifier
        project_name: String,
        /// Project object address
        project_object_address: address,
        /// Project owner address
        owner: address
    }

    public fun patch_data<T: drop, Data>(new_data: Data, witness: T) {
        let(pass, project_address) = verify_identity<T>(witness);
        // 可以使用 Data 类型做准入判断（只允许特定记个类型的数据写在 namespace 下）
        move_to(obj_signer, new_data);

    }

    public fun get_data_mut_by_witness<T: drop, Data>(witness: T) &mut Data {
        let(pass, project_address) = verify_identity<T>(witness);
    }

    public fun get_data_by_project<T: drop, Data>(project: address, witness: T) &Data {
        let pass = caas_authentication::verify_authentication<T>(project, witness);
        // 验证

    }
    
}

