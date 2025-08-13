module caas_framework::namespace {

    use std::signer;
    use std::vector;
    use std::string::{String};
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_std::smart_table::{Self, SmartTable};
    use caas_framework::identity::{verify_identity};
    use caas_framework::authorization::{verify_read_authorization};
    use aptos_framework::object::{Self, Object, ExtendRef, TransferRef};

    /// Namespace registry (stored under @caas_framework)
    struct NamespaceRegistry has key {
        /// Creator address → namespace list
        // creator_to_namespaces: SmartTable<address, vector<address>>,

        /// Project address → namespace list (a project can have multiple namespaces)
        project_to_namespaces: SmartTable<address, vector<address>>,

        /// Creation time index (bucketed by day)
        /// TODO: I don't understand what the use case of this field
        // creation_time_index: SmartTable<u64, vector<address>>,

        /// Statistics
        total_namespaces: u64,
        total_root_spaces: u64,
        total_sub_spaces: u64
    }

    /// Namespace object metadata (stored under each namespace object address)
    struct NamespaceCore has key {

        /// Associated project info
        project_info: address,

        /// extend ref for future resources patching
        extend_ref: ExtendRef,

        transfer_ref: TransferRef,
        
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
        // subspace_creation_permission: u8,

        /// Whether ownership is transferable
        is_transferable: bool,

        /// Whether public (public namespaces can be read by anyone)
        is_public: bool,

        /// Whether sharing via authorization system is allowed
        allow_authorization: bool,

        /// Direct access control list (project addresses)
        access_control_list: vector<address>
    }

    struct Container<DataType: store> has key {
        data: Option<DataType>
    }

    struct Voucher<DataType: store> {
        namespace: address
    }

    const EWITNESS_VERIFIED_FAILED: u64 = 1;
    const ENO_PERMISSION_TO_ACCESS_NAMESPACE: u64 = 2;
    const ENAMESPACE_PROJECT_NOT_MATCH: u64 = 3;
    const ENAMESPACE_NOT_EXISTS: u64 = 4;
    const EWITNESS_PROJECT_NOT_MATCH: u64 = 5;

    fun init_module(sender: &signer) {
        move_to(sender, NamespaceRegistry{
            project_to_namespaces: smart_table::new<address, vector<address>>(),

            /// Creation time index (bucketed by day)
            /// TODO: I don't understand what the use case of this field
            // creation_time_index: SmartTable<u64, vector<address>>,

            /// Statistics
            total_namespaces: 0,
            total_root_spaces: 0,
            total_sub_spaces: 0
        })
    }

    public fun create_namespace<T: drop>(
        witness: T, 
        parent_space: Option<Object<NamespaceCore>>
    ) acquires NamespaceCore {
        let project_address = verify_witness_return_project_address(witness);
        let construct_ref = object::create_object(project_address);
        let obj_signer = object::generate_signer(&construct_ref);
        let parent = if(parent_space.is_some()) {
            let parent_namespace_obj_address = object::object_address(&parent_space.destroy_some());
            let parent_namespace_core = borrow_global_mut<NamespaceCore>(parent_namespace_obj_address);
            parent_namespace_core.children.push_back(signer::address_of(&obj_signer));
            option::some(parent_namespace_obj_address)
        } else {
            option::destroy_none(parent_space);
            option::none<address>()
        };
        move_to(&obj_signer, NamespaceCore{
            /// Associated project info
            project_info: project_address,

            /// extend ref for future resources patching
            extend_ref: object::generate_extend_ref(&construct_ref),

            transfer_ref: object::generate_transfer_ref(&construct_ref),
            
            /// Parent namespace address (None for root namespace)
            parent,

            /// List of child namespaces
            children: vector::empty<address>(),

            /// Timestamps
            created_at: timestamp::now_seconds(),
            updated_at: timestamp::now_seconds(),

            /// Whether verified by CaaS
            /// TODO: What's the verfiy process?
            is_verified: false,

            /// Namespace attributes (key-value storage)
            attributes: smart_table::new<String, String>(),

            /// Access statistics
            access_count: 0,
            last_accessed: 0

        })

    }

    public fun patch_data<T: drop, DataType: store>(
        namespace: Object<NamespaceCore>,
        data: DataType,
        witness: T
    ) acquires NamespaceCore {
        let _project_address = verify_witness_return_project_address(witness);
        // 可以使用 Data 类型做准入判断（只允许特定记个类型的数据写在 namespace 下）
        let core_data = borrow_global_mut<NamespaceCore>(object::object_address(&namespace));
        let obj_signer = object::generate_signer_for_extending(&core_data.extend_ref);
        move_to(&obj_signer, Container{
            data: option::some(data)
        });
    }

    public fun get_data_by_witness<T: drop, DataType: store>(
        namespace: Object<NamespaceCore>, 
        witness: T
    ): (DataType, Voucher<DataType>) acquires NamespaceCore, Container {
        let project_address = verify_witness_return_project_address(witness);
        let namespace_project_address = get_project_address_by_namespace(namespace);
        assert!(project_address == namespace_project_address, EWITNESS_PROJECT_NOT_MATCH);
        let obj_address = object::object_address(&namespace);
        let core_data = borrow_global_mut<NamespaceCore>(obj_address);
        let obj_signer = object::generate_signer_for_extending(&core_data.extend_ref);
        let container = move_from<Container<DataType>>(obj_address);
        let data = container.data.extract();
        move_to(&obj_signer, container);
        (data, Voucher<DataType>{
            namespace: obj_address
        })
    }

    public fun get_data_by_project<T: drop, DataType: store>(
        namespace: Object<NamespaceCore>, 
        project: address, 
        witness: T
    ): (DataType, Voucher<DataType>) acquires NamespaceCore, Container {
        let obj_address = object::object_address(&namespace);
        let namespace_core = borrow_global_mut<NamespaceCore>(obj_address);
        assert!(namespace_core.project_info == project, ENAMESPACE_PROJECT_NOT_MATCH);
        // TODO: authorization level should be considered here, maybe the different level could access to different subspace
        let pass = verify_read_authorization(witness, project);
        assert!(pass, ENO_PERMISSION_TO_ACCESS_NAMESPACE);
        let core_data = borrow_global_mut<NamespaceCore>(obj_address);
        let obj_signer = object::generate_signer_for_extending(&core_data.extend_ref);
        let container = move_from<Container<DataType>>(obj_address);
        let data = container.data.extract();
        move_to(&obj_signer, container);
        (data, Voucher<DataType>{
            namespace: obj_address
        })
    }

    public fun return_data<DataType: store>(data: DataType, voucher: Voucher<DataType>) acquires NamespaceCore, Container {
        let Voucher{
            namespace: namespace_address
        } = voucher;
        let container = move_from<Container<DataType>>(namespace_address);
        let core_data = borrow_global_mut<NamespaceCore>(namespace_address);
        let obj_signer = object::generate_signer_for_extending(&core_data.extend_ref);
        container.data.fill(data);
        move_to(&obj_signer, container);
    }

    fun verify_witness_return_project_address<T: drop>(witness: T): address {
        let(pass, project_address) = verify_identity<T>(witness);
        assert!(pass, EWITNESS_VERIFIED_FAILED);
        project_address
    }

    #[view]
    public fun get_project_address_by_namespace(namespace: Object<NamespaceCore>): address acquires NamespaceCore {

        let namespace_obj_address = object::object_address(&namespace);
        assert!(exists<NamespaceCore>(namespace_obj_address), ENAMESPACE_NOT_EXISTS);
        let namespace_core = borrow_global<NamespaceCore>(namespace_obj_address);
        namespace_core.project_info

    }
    
}

