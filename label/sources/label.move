module use_case::label {
    use std::vector;
    use std::signer;
    use aptos_std::type_info;
    use aptos_framework::event;
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::smart_vector::{Self, SmartVector};

    use caas_framework::identity::verify_identity;
    use caas_framework::namespace::{Self, NamespaceCore, Voucher, get_data_by_witness, get_data_by_project};

    struct Label has store {
        enums: SmartVector<String>,
        labels: SmartTable<address, SmartVector<String>>
    }

    #[event]
    struct AddLabelEnumEvent has copy, drop, store {
        admin: address,
        label: String
    }

    #[event]
    struct AddUserLabelEvent has copy, drop, store {
        user: address,
        label: String
    }

    #[event]
    struct RemoveUserLabelEvent has copy, drop, store {
        user: address,
        label: String
    }

    const ELABEL_ENUM_ALREADY_CONTAINS: u64 = 1;
    const EENUM_NOT_EXISTS: u64 = 2;
    const EADDRESS_ALREADY_LABELED: u64 = 3;
    const EADDRESS_NEVER_BEEN_LABELED: u64 = 4;
    const EADDRESS_NOT_LABELED: u64 = 5;

    public fun create_label<T: drop>(namespace: Object<NamespaceCore>, witness: T) {
        let new_label = Label {
            enums: smart_vector::new<String>(),
            labels: smart_table::new<address, SmartVector<String>>(),
        };

        namespace::patch_data<T, Label>(namespace, new_label, witness);
    }

//  Users must ensure the security of witness transmission (only pass witness to caas services, caas services ensure it's consumed and discarded)
    public fun add_enums<T: drop>(namespace: Object<NamespaceCore>, new_enum: String, witness: T) {
        let (label_record, voucher) = namespace::get_data_by_witness<T, Label>(namespace, witness);
        assert!(!label_record.enums.contains(&new_enum), ELABEL_ENUM_ALREADY_CONTAINS);
        label_record.enums.push_back(new_enum);
        namespace::return_data(label_record, voucher);
        // event::emit(AddLabelEnumEvent{
        //     project_address,
        //     label: new_enum
        // })
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
        // event::emit(AddAddressLabelEvent{
        //     address_labeled: address_to_label,
        //     label
        // });
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
        // event::emit(RemoveAddressLabelEvent{
        //     address_labeled: address_to_label,
        //     label
        // });
    }

    fun get_labels_by_witness<T: drop>(namespace: Object<NamespaceCore>, witness: T): (Label, Voucher<Label>) {
        namespace::get_data_by_witness<T, Label>(namespace, witness)
    }

    fun get_labels_by_project<T: drop>(namespace: Object<NamespaceCore>, project: address, witness: T): (Label, Voucher<Label>) {
        namespace::get_data_by_project<T, Label>(namespace, project, witness)
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

}

