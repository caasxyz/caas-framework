module caas_framework::two_step_transfer_object {
    use std::signer;
    use std::bcs::{to_bytes};
    use aptos_framework::event;
    use aptos_framework::object::{Self, ObjectCore, ExtendRef, DeleteRef};

    struct ObjectExchange has key, drop {
        exchange_holder: ExtendRef,
        object_address: address,
        previous_owner: address,
        pending_owner: address,
        exchange_delete_ref: DeleteRef
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

    public entry fun transfer_object(owner: &signer, object_address: address, to: address) {
        let owner_address = signer::address_of(owner);
        let object_to_transfer = object::address_to_object<ObjectCore>(object_address); 
        let is_owner = object::is_owner<ObjectCore>(object_to_transfer, owner_address);
        assert!(is_owner, ENOT_OBJECT_OWNER);
        let construct_ref = object::create_named_object(owner, to_bytes(&object_address));
        let delete_ref = object::generate_delete_ref(&construct_ref);
        let extend_ref = object::generate_extend_ref(&construct_ref);
        let exchange_signer = object::generate_signer_for_extending(&extend_ref);
        let exchange_holder_address = object::address_from_extend_ref(&extend_ref); 
        object::transfer_call(owner, object_address, exchange_holder_address);

        move_to(&exchange_signer, ObjectExchange{
            exchange_holder: extend_ref,
            object_address,
            previous_owner: owner_address,
            pending_owner: to,
            exchange_delete_ref: delete_ref
        });

        event::emit(ObjectExchangeCreated{
            object_address,
            previous_owner: owner_address,
            exchange_address: exchange_holder_address,
            pending_owner: to
        });
    }

    public entry fun claim_owner(sender: &signer, object_address: address, previous_owner: address) acquires ObjectExchange {
        let claimer = signer::address_of(sender);
        let exchange_address = object::create_object_address(&previous_owner, to_bytes(&object_address));
        let ObjectExchange{
            exchange_holder,
            object_address: object_address_to_check,
            previous_owner: _,
            pending_owner,
            exchange_delete_ref
        } = move_from<ObjectExchange>(exchange_address);
        assert!(claimer == pending_owner, EWRONG_CLAIMER);
        assert!(object_address == object_address_to_check, EWRONG_OBJECT_ADDRESS);
        let exchange_signer = object::generate_signer_for_extending(&exchange_holder);
        object::transfer_call(&exchange_signer, object_address, claimer);
        object::delete(exchange_delete_ref);

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
        let ObjectExchange{
            exchange_holder,
            object_address: object_address_to_check,
            previous_owner,
            pending_owner,
            exchange_delete_ref
        } = move_from<ObjectExchange>(exchange_address);
        assert!(object_address == object_address_to_check, EWRONG_OBJECT_ADDRESS);
        assert!(owner_address == previous_owner, ENOT_OBJECT_OWNER);
        let exchange_signer = object::generate_signer_for_extending(&exchange_holder);
        object::transfer_call(&exchange_signer, object_address, owner_address);
        object::delete(exchange_delete_ref);

        event::emit(ObjectExchangeRevoked{
            object_address,
            current_owner: owner_address,
            exchange_address,
            pending_owner 
        });
    }
}