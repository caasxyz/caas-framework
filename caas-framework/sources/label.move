module caas_framework::label {
    use aptos_std::type_info;
    use aptos_framework::event;
    use std::string::{String};
    use aptos_framework::object::{Object};
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::smart_vector::{Self, SmartVector};

    use caas_framework::namespace::{Self, NamespaceCore, Voucher};

    struct Label has store {
        enums: SmartVector<String>,
        labels: SmartTable<address, SmartVector<String>>
    }

    #[event]
    struct CreateLabelSpaceEvent has copy, drop, store {
        project_address: address,
        namespace: Object<NamespaceCore>
    }

    #[event]
    struct AddLabelEnumEvent has copy, drop, store {
        project_address: address,
        namespace: Object<NamespaceCore>,
        label: String
    }

    #[event]
    struct SetLabelEvent has copy, drop, store {
        key: address,
        label: String
    }

    #[event]
    struct RemoveLabelEvent has copy, drop, store {
        key: address,
        label: String
    }

    const ELABEL_ENUM_ALREADY_CONTAINS: u64 = 1;
    const EENUM_NOT_EXISTS: u64 = 2;
    const EADDRESS_ALREADY_LABELED: u64 = 3;
    const EADDRESS_NEVER_BEEN_LABELED: u64 = 4;
    const EADDRESS_NOT_LABELED: u64 = 5;

    public fun create<T: drop>(namespace: Object<NamespaceCore>, witness: T) {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let new_label = Label {
            enums: smart_vector::new<String>(),
            labels: smart_table::new<address, SmartVector<String>>(),
        };

        namespace::patch_data<T, Label>(namespace, new_label, witness);

        event::emit(CreateLabelSpaceEvent{
            project_address: type_info_address,
            namespace
        });
    }

//  Users must ensure the security of witness transmission (only pass witness to caas services, caas services ensure it's consumed and discarded)
    public fun add_enums<T: drop>(namespace: Object<NamespaceCore>, new_enum: String, witness: T) {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let (label_record, voucher) = namespace::get_data_by_witness<T, Label>(namespace, witness);
        assert!(!label_record.enums.contains(&new_enum), ELABEL_ENUM_ALREADY_CONTAINS);
        label_record.enums.push_back(new_enum);
        namespace::return_data(label_record, voucher);
        event::emit(AddLabelEnumEvent{
            project_address: type_info_address,
            namespace,
            label: new_enum
        })
    }

    public(package) fun add_enums_internal<T: drop>(namespace: Object<NamespaceCore>, new_enum: String) {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let (label_record, voucher) = namespace::get_data_by_type_internal<T, Label>(namespace);
        assert!(!label_record.enums.contains(&new_enum), ELABEL_ENUM_ALREADY_CONTAINS);
        label_record.enums.push_back(new_enum);
        namespace::return_data(label_record, voucher);
        event::emit(AddLabelEnumEvent{
            project_address: type_info_address,
            namespace,
            label: new_enum
        })
    }

    public fun set_label<T: drop>(namespace: Object<NamespaceCore>, address_to_label: address, label: String, witness: T) {
        let (label_record, voucher) = namespace::get_data_by_witness<T, Label>(namespace, witness);
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);

        if(!label_record.labels.contains(address_to_label)) {
            label_record.labels.add(address_to_label, smart_vector::new<String>());
        };
        let address_labels = label_record.labels.borrow_mut(address_to_label);
        assert!(!address_labels.contains(&label), EADDRESS_ALREADY_LABELED);
        address_labels.push_back(label);
        namespace::return_data(label_record, voucher);
        event::emit(SetLabelEvent{
            key: address_to_label,
            label
        });
    }

    public(package) fun set_label_internal<T: drop>(namespace: Object<NamespaceCore>, address_to_label: address, label: String) {
        let (label_record, voucher) = namespace::get_data_by_type_internal<T, Label>(namespace);
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);

        if(!label_record.labels.contains(address_to_label)) {
            label_record.labels.add(address_to_label, smart_vector::new<String>());
        };
        let address_labels = label_record.labels.borrow_mut(address_to_label);
        assert!(!address_labels.contains(&label), EADDRESS_ALREADY_LABELED);
        address_labels.push_back(label);
        namespace::return_data(label_record, voucher);
        event::emit(SetLabelEvent{
            key: address_to_label,
            label
        });
    }

    public fun remove_label<T: drop>(namespace: Object<NamespaceCore>, address_to_remove_label: address, label: String, witness: T) {
        let (label_record, voucher) = namespace::get_data_by_witness<T, Label>(namespace, witness);
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);

        assert!(label_record.labels.contains(address_to_remove_label), EADDRESS_NEVER_BEEN_LABELED);
        let address_labels = label_record.labels.borrow_mut(address_to_remove_label);
        assert!(address_labels.contains(&label), EADDRESS_NOT_LABELED);
        let (_found, index) = address_labels.index_of(&label); 
        address_labels.remove(index);
        namespace::return_data(label_record, voucher);
        event::emit(RemoveLabelEvent{
            key: address_to_remove_label,
            label
        });
    }

    public(package) fun remove_label_internal<T: drop>(namespace: Object<NamespaceCore>, address_to_remove_label: address, label: String) {
        let (label_record, voucher) = namespace::get_data_by_type_internal<T, Label>(namespace);
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);

        assert!(label_record.labels.contains(address_to_remove_label), EADDRESS_NEVER_BEEN_LABELED);
        let address_labels = label_record.labels.borrow_mut(address_to_remove_label);
        assert!(address_labels.contains(&label), EADDRESS_NOT_LABELED);
        let (_found, index) = address_labels.index_of(&label); 
        address_labels.remove(index);
        namespace::return_data(label_record, voucher);
        event::emit(RemoveLabelEvent{
            key: address_to_remove_label,
            label
        });
    }

    fun get_labels_by_witness<T: drop>(namespace: Object<NamespaceCore>, witness: T): (Label, Voucher<Label>) {
        namespace::get_data_by_witness<T, Label>(namespace, witness)
    }

    fun get_labels_by_project<T: drop>(namespace: Object<NamespaceCore>, project: address, witness: T): (Label, Voucher<Label>) {
        namespace::get_data_by_project<T, Label>(namespace, project, witness)
    }

    fun get_labels_by_type<T: drop>(namespace: Object<NamespaceCore>): (Label, Voucher<Label>) {
        namespace::get_data_by_type_internal<T, Label>(namespace)
    }

    public fun has_label<T: drop>(
        namespace: Object<NamespaceCore>, 
        address_to_check: address, 
        label: String, 
        witness: T
    ): bool {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let namespace_project_address = namespace::get_project_address_by_namespace(namespace);
        let (label_record, voucher) = if(type_info_address == namespace_project_address) {
            get_labels_by_witness(namespace, witness)
        } else {
            get_labels_by_project(namespace, type_info_address, witness)
        };
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);
        let whether_have_label = if(label_record.labels.contains(address_to_check)) {
            let address_labels = label_record.labels.borrow(address_to_check);
            address_labels.contains(&label)
        } else {
            false
        };
        namespace::return_data(label_record, voucher);
        whether_have_label
    }

    public(package) fun has_label_internal<T: drop>(
        namespace: Object<NamespaceCore>, 
        address_to_check: address, 
        label: String, 
    ): bool {
        let (label_record, voucher) = get_labels_by_type<T>(namespace);
        assert!(label_record.enums.contains(&label), EENUM_NOT_EXISTS);
        let whether_have_label = if(label_record.labels.contains(address_to_check)) {
            let address_labels = label_record.labels.borrow(address_to_check);
            address_labels.contains(&label)
        } else {
            false
        };
        namespace::return_data(label_record, voucher);
        whether_have_label
    }

    public fun has_label_enum<T: drop>(
        namespace: Object<NamespaceCore>,
        label: String,
        witness: T
    ): bool {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let namespace_project_address = namespace::get_project_address_by_namespace(namespace);
        let (label_record, voucher) = if(type_info_address == namespace_project_address) {
            get_labels_by_witness(namespace, witness)
        } else {
            get_labels_by_project(namespace, type_info_address, witness)
        };
        let whether_have_label_enum = label_record.enums.contains(&label);
        namespace::return_data(label_record, voucher);
        whether_have_label_enum
    }

    public(package) fun has_label_enum_internal<T: drop>(
        namespace: Object<NamespaceCore>,
        label: String
    ): bool {
        let (label_record, voucher) = get_labels_by_type<T>(namespace);
        let whether_have_label_enum = label_record.enums.contains(&label);
        namespace::return_data(label_record, voucher);
        whether_have_label_enum
    }

    public fun get_address_labels<T: drop>(
        namespace: Object<NamespaceCore>,
        address_to_check: address,
        witness: T
    ): vector<String> {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let namespace_project_address = namespace::get_project_address_by_namespace(namespace);
        let (label_record, voucher) = if(type_info_address == namespace_project_address) {
            get_labels_by_witness(namespace, witness)
        } else {
            get_labels_by_project(namespace, type_info_address, witness)
        };
        let label_list = if(label_record.labels.contains(address_to_check)) {
            let address_labels = label_record.labels.borrow(address_to_check);
            address_labels.to_vector()
        } else {
            vector<String>[]
        };
        namespace::return_data(label_record, voucher);
        label_list
    }

    public fun does_label_initialized<T: drop>(
        namespace: Object<NamespaceCore>,
        witness: T
    ): bool {
        namespace::has_data_container<T, Label>(namespace, witness)
    }

    public(package) fun does_label_initialized_internal<T: drop>(
        namespace: Object<NamespaceCore>,
    ): bool {
        namespace::has_data_container_internal<T, Label>(namespace)
    }

}

