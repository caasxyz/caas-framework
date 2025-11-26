module caas_framework::context {

    use aptos_std::type_info;
    use std::string::String;
    use aptos_framework::event;
    use aptos_framework::object::{ Object};
    use std::option::{Self, Option};
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::transaction_context;

    use caas_framework::namespace::{Self, NamespaceCore, Voucher};

    struct Context has store {
        data_list: SmartTable<String, vector<u8>>,
        in_use: bool
    }

    struct Order {
        namespace: Object<NamespaceCore>,
        txn_id: vector<u8>
    }

    #[event]
    struct CreateContextEvent has copy, store, drop {
        project_address: address,
        namespace: Object<NamespaceCore>
    }

    const NOT_THE_SAME_TRANSACTION: u64 = 1;
    const EKEY_EXISTS: u64 = 2;
    const ENOT_THE_SAME_TRANSACTION: u64 = 3;
    const ENOT_THE_SAME_NAMESPACE: u64 = 4;
    const ENO_DATA_VALUE: u64 = 5;

    public fun create<T: drop>(namespace: Object<NamespaceCore>, witness: T) {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let new_context = Context {
            data_list: smart_table::new<String, vector<u8>>(),
            in_use: false,
        };

        namespace::patch_data<T, Context>(namespace, new_context, witness);

        event::emit(CreateContextEvent{
            project_address: type_info_address,
            namespace
        });
    }

    public fun set_data<T: drop>(
        namespace: Object<NamespaceCore>, 
        key: String, 
        value: vector<u8>,
        witness: T
    ): Option<Order> {
        let (context, voucher) = namespace::get_data_by_witness<T, Context>(namespace, witness);
        context.data_list.upsert(key, value);

        let ret = if(context.in_use) {
            option::none<Order>()
        } else {
            let order = Order {
                txn_id: transaction_context::get_transaction_hash(),
                namespace
            };
            context.in_use = true;
            option::some(order)
        };
        namespace::return_data(context, voucher);
        ret
    }

    public fun clear<T: drop>(namespace: Object<NamespaceCore>, order: Order, witness: T) {
        let (context, voucher) = namespace::get_data_by_witness<T, Context>(namespace, witness);
        let current_txn_id = transaction_context::get_transaction_hash();
        let Order {
            txn_id: txn_id,
            namespace: namespace_
        } = order;
        assert!(txn_id == current_txn_id, ENOT_THE_SAME_TRANSACTION);
        assert!(namespace == namespace_, ENOT_THE_SAME_NAMESPACE);
        context.data_list.clear();
        context.in_use = false;
        namespace::return_data(context, voucher);
    }

    public fun get_data_value<T: drop>(
        namespace: Object<NamespaceCore>, 
        key: String, 
        witness: T
    ): Option<vector<u8>> {
        let witness_type_info = type_info::type_of<T>();
        let type_info_address = type_info::account_address(&witness_type_info);
        let namespace_project_address = namespace::get_project_address_by_namespace(namespace);
        let (context, voucher) = if(type_info_address == namespace_project_address) {
            get_context_by_witness(namespace, witness)
        } else {
            get_context_by_project(namespace, type_info_address, witness)
        };
        let data_value = if(context.data_list.contains(key)) {
            option::some(*context.data_list.borrow(key)) 
        } else {
            option::none<vector<u8>>()
        };
        namespace::return_data(context, voucher);
        data_value
    }

    #[module_lock]
    public fun get_data_value_with_deserializer<T: drop, DataType>(
        namespace: Object<NamespaceCore>,
        key: String,
        witness: T, 
        deserializer: |vector<u8>|(DataType)
    ): DataType {
        let data_value_opt = get_data_value<T>(namespace, key, witness);
        assert!(data_value_opt.is_some(), ENO_DATA_VALUE);
        let data_value = data_value_opt.destroy_some();
        deserializer(data_value)
    }

    fun get_context_by_witness<T: drop>(namespace: Object<NamespaceCore>, witness: T): (Context, Voucher<Context>) {
        namespace::get_data_by_witness<T, Context>(namespace, witness)
    }

    fun get_context_by_project<T: drop>(
        namespace: Object<NamespaceCore>, 
        project: address, 
        witness: T
    ): (Context, Voucher<Context>) {
        namespace::get_data_by_project<T, Context>(namespace, project, witness)
    }

}