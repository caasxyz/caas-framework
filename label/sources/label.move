module caas::label {
    use std::string::{Self, String};
    use std::vector;
    use std::signer;
    use aptos_std::event;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::smart_vector::{Self, SmartVector};
    use dex_contract::package_manager::{Self, assert_admin};

    use caas_indentity::identity::verify_identity;
    use caas_indentity::namespace::{get_data_mut_by_witness, get_data_by_project};

    struct Label has key {
        enums: SmartVector<String>
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

    public fun create_label<T: drop>(witness: T) {
        let new_label = Label {
            enums: smart_vector::new<String>()
            labels: smart_table::new<address, SmartVector<String>>(),
        };

        caas_namespace::add_new_data<T: drop>(new_label, witness)
    }

//  用户自己确保 witnesss 的传输安全性（只能把 witness 传到 caas 里的服务，caas 服务确保会用完丢掉）
    public fun add_enums<T: drop>(new_enum: String, witness: T) {
        let label_mut = get_data_mut_by_witness<T, Label>(witness);

    }

    public fun get_labels<T: drop>(project_to_fetch: address, witness: T) {
        let label = get_data_by_project_address<T, Label>(witness, project_to_fetch);

    }

}

