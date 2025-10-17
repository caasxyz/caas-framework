module caas_framework::two_step_transfer_object {
    use std::signer;
    use std::bcs::{to_bytes};
    use aptos_framework::event;
    use aptos_framework::object::{Self, ObjectCore, ExtendRef};

    struct ObjectExchange has key {
        exchange_holder: ExtendRef,
        object_address: address,
        previous_owner: address,
        pending_owner: address,
        exchange_stomb_mark: bool
    }

    #[event]
    struct ObjectExchangeCreated has store, copy, drop {
        object_address: address,
        previous_owner: address,
        exchange_address: address,
        pending_owner: address
    }

    #[event]
    struct ObjectExchangeRevoked has store, copy, drop {
        object_address: address,
        current_owner: address,
        exchange_address: address,
        pending_owner: address
    }

    #[event]
    struct ObjectExchangeClaimed has store, copy, drop {
        object_address: address,
        old_owner: address,
        exchange_address: address,
        new_owner: address
    }

    const ENOT_OBJECT_OWNER: u64 = 1;
    const EWRONG_CLAIMER: u64 = 2;
    const EWRONG_OBJECT_ADDRESS: u64 = 3;
    const EWRONG_PREVIOUS_OWNER: u64 = 4;
    const EEXCHANGE_DEPRECATED: u64 = 5;
    const EEXCHANGE_ALREADY_SETTED: u64 = 6;

    // Use owner and object to generate an exchange object, which will be the main record for each transfer/revoke operation initiated by the owner.
    // The exchange_stomb_mark is used as a flag to indicate whether there is a pending object transfer. This design allows external tracking of transfer records.
    public entry fun transfer_object(owner: &signer, object_address: address, to: address) acquires ObjectExchange {
        let owner_address = signer::address_of(owner);
        let object_to_transfer = object::address_to_object<ObjectCore>(object_address); 
        let is_owner = object::is_owner<ObjectCore>(object_to_transfer, owner_address);
        assert!(is_owner, ENOT_OBJECT_OWNER);
        let exchange_object_address = object::create_object_address(&owner_address, to_bytes(&object_address));
        if(!object::object_exists<ObjectExchange>(exchange_object_address)) {
            initialize_exchange(owner, object_address, to);
        };
        let exchange = borrow_global_mut<ObjectExchange>(exchange_object_address);
        assert!(exchange.exchange_stomb_mark, EEXCHANGE_ALREADY_SETTED);

        object::transfer_call(owner, object_address, exchange_object_address);
        exchange.exchange_stomb_mark = false;
        exchange.previous_owner = owner_address;
        exchange.pending_owner = to;
        exchange.object_address = object_address;


        event::emit(ObjectExchangeCreated{
            object_address,
            previous_owner: owner_address,
            exchange_address: exchange_object_address,
            pending_owner: to
        });
    }

    public entry fun claim_owner(sender: &signer, object_address: address, previous_owner: address) acquires ObjectExchange {
        let claimer = signer::address_of(sender);
        let exchange_address = object::create_object_address(&previous_owner, to_bytes(&object_address));
        let exchange = borrow_global_mut<ObjectExchange>(exchange_address);
        assert!(!exchange.exchange_stomb_mark, EEXCHANGE_DEPRECATED);
        assert!(claimer == exchange.pending_owner, EWRONG_CLAIMER);
        assert!(object_address == exchange.object_address, EWRONG_OBJECT_ADDRESS);
        assert!(previous_owner == exchange.previous_owner, EWRONG_PREVIOUS_OWNER);
        let exchange_signer = object::generate_signer_for_extending(&exchange.exchange_holder);
        object::transfer_call(&exchange_signer, object_address, claimer);
        exchange.exchange_stomb_mark = true;

        event::emit(ObjectExchangeClaimed{
            object_address,
            old_owner: previous_owner,
            exchange_address,
            new_owner: claimer
        });
    }

    public entry fun revoke_transfer(owner: &signer, object_address: address) acquires ObjectExchange {
        let owner_address = signer::address_of(owner);
        let exchange_address = object::create_object_address(&owner_address, to_bytes(&object_address));
        let exchange = borrow_global_mut<ObjectExchange>(exchange_address);
        assert!(!exchange.exchange_stomb_mark, EEXCHANGE_DEPRECATED);
        assert!(object_address == exchange.object_address, EWRONG_OBJECT_ADDRESS);
        assert!(owner_address == exchange.previous_owner, ENOT_OBJECT_OWNER);
        let exchange_signer = object::generate_signer_for_extending(&exchange.exchange_holder);
        object::transfer_call(&exchange_signer, object_address, owner_address);
        exchange.exchange_stomb_mark = true;

        event::emit(ObjectExchangeRevoked{
            object_address,
            current_owner: owner_address,
            exchange_address,
            pending_owner: exchange.pending_owner 
        });
    }

    fun initialize_exchange(owner: &signer, object_address: address, to: address) {
        let owner_address = signer::address_of(owner);
        let construct_ref = object::create_named_object(owner, to_bytes(&object_address));
        let extend_ref = object::generate_extend_ref(&construct_ref);
        let exchange_signer = object::generate_signer_for_extending(&extend_ref);

        move_to(&exchange_signer, ObjectExchange{
            exchange_holder: extend_ref,
            object_address,
            previous_owner: owner_address,
            pending_owner: to,
            exchange_stomb_mark: true
        });
    }
}