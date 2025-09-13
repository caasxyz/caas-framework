module caas_framework::passkey {

    use std::bcs;
    use std::vector;
    use std::signer;
    use aptos_std::from_bcs;
    use std::string::{String};
    use aptos_framework::event;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::object::{Self, ExtendRef};

    struct Witness has drop {}

    struct PasskeyManagement has key {
        extend_ref: ExtendRef
    }

    struct UserPasskey<phantom ProjectType> has key {
        infos: SmartTable<address, PasskeyInfo>,
    }

    struct PasskeyInfo has store, copy, drop {
        domain: String,
        passkey_id: String,
        public_key: vector<u8>, 
        // TODO: data length limit
        extra_data: vector<u8>
    }

    struct PasskeyInfoForView has store, copy, drop {
        domain: String,
        passkey_id: String,
        public_key: address,
        extra_data: vector<u8>
    }

    #[event]
    struct PasskeyInitializedEvent<phantom T> has store, copy, drop {
        user_address: address,
        project_signer_address: address,
        passkey_id: String,
        public_key: address,
        domain: String,
        extra_data: vector<u8>
    }

    #[event]
    struct PasskeyRegisteredEvent<phantom T> has store, copy, drop {
        user_address: address,
        project_signer_address: address,
        passkey_id: String,
        public_key: address,
        domain: String,
        extra_data: vector<u8>
    }


    // for testing
    struct TestType has drop {}

    const EALREADY_REGISTERED: u64 = 1;
    const ENO_PASSKEY_REGISTERED: u64 = 2;
    const EPASSKEY_NOT_CONTAINED: u64 = 3;
    const EPASSKEY_NOT_VALID: u64 = 4;
    const EPASSKEY_NOT_INITIALIZED: u64 = 5;
    const EPASSKEY_NOT_FOUND: u64 = 6;
    const EEXTRA_DATA_TOO_LONG: u64 = 7;

    const SEED: vector<u8> = b"CAAS-PASSKEY";
    const EXTRA_DATA_MAX_LENGTH: u64 = 500;

    //TODO: label passkey account when added
    public entry fun initialize<T: drop>(
        user: &signer, 
        project_signer: &signer,
        passkey_address: address, 
        public_key: address,
        passkey_id: String, 
        domain: String,
        extra_data: vector<u8>
    ) acquires PasskeyManagement, UserPasskey {
        // TODO: check out whether project has been registered in caas
        let user_address = signer::address_of(user);
        let project_signer_address = signer::address_of(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert_extra_data_length(&extra_data);
        if(!object::object_exists<PasskeyManagement>(passkey_object_address)) {
            let construct_ref = object::create_named_object(user, SEED);
            let object_signer = object::generate_signer(&construct_ref);
            let extend_ref = object::generate_extend_ref(&construct_ref);
            move_to(&object_signer, PasskeyManagement{
                extend_ref
            });
        };
        let management = borrow_global<PasskeyManagement>(passkey_object_address);
        let passkey_object_signer = object::generate_signer_for_extending(&management.extend_ref);
        if(!exists<UserPasskey<T>>(passkey_object_address)) {
            move_to(&passkey_object_signer, UserPasskey<T>{
                infos: smart_table::new<address, PasskeyInfo>()
            });
        };
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        assert!(!user_passkeys.infos.contains(passkey_address), EALREADY_REGISTERED);
        user_passkeys.infos.add(passkey_address, PasskeyInfo{
            domain,
            public_key: bcs::to_bytes(&public_key),
            passkey_id,
            extra_data
        });
        event::emit(PasskeyInitializedEvent<T>{
            user_address,
            project_signer_address,
            passkey_id,
            public_key,
            domain,
            extra_data
        });
    }

    public entry fun register_when_exists<T: drop>(
        user: &signer, 
        passkey_signer: &signer, 
        project_signer: &signer,
        passkey_address: address,
        public_key: address,
        passkey_id: String,
        domain: String,
        extra_data: vector<u8>
    ) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_signer_address = signer::address_of(passkey_signer);
        let project_signer_address = signer::address_of(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert_extra_data_length(&extra_data);
        assert!(object::object_exists<UserPasskey<T>>(passkey_object_address), EPASSKEY_NOT_INITIALIZED);
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.contains(passkey_signer_address), EPASSKEY_NOT_VALID);
        user_passkeys.infos.add(passkey_address, PasskeyInfo{
            domain,
            public_key: bcs::to_bytes(&public_key),
            passkey_id,
            extra_data
        });
        event::emit(PasskeyRegisteredEvent<T>{
            user_address,
            project_signer_address,
            passkey_id,
            public_key,
            domain,
            extra_data

        });
    }

    public entry fun remove_passkey<T: drop>(
        user: &signer, 
        passkey_signer: &signer, 
        project_signer: &signer,
        to_remove: address
    ) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_signer_address = signer::address_of(passkey_signer);
        let _project_signer_address = signer::address_of(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert!(object::object_exists<UserPasskey<T>>(passkey_object_address), EPASSKEY_NOT_INITIALIZED);
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.contains(passkey_signer_address), EPASSKEY_NOT_VALID);
        assert!(user_passkeys.infos.contains(to_remove), EPASSKEY_NOT_FOUND);
        user_passkeys.infos.remove(to_remove);
        // TODO: emit event
    }

    #[view]
    public fun is_user_registered<T: drop>(user_address: address): bool acquires UserPasskey {
        let passkey_object_address = get_user_passkey_object_address(user_address); 
        if(object::object_exists<UserPasskey<T>>(passkey_object_address)) {
            let user_passkeys = borrow_global<UserPasskey<T>>(passkey_object_address);
            if(user_passkeys.infos.length() == 0) {
                return false
            } else {
                return true
            }
        } else {
            return false
        } 
    }

    #[view]
    public fun user_passkey_list<T: drop>(user_address: address): vector<PasskeyInfoForView> acquires UserPasskey {
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert!(exists<UserPasskey<T>>(passkey_object_address), ENO_PASSKEY_REGISTERED);
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        let user_passkey_address_list = user_passkeys.infos.keys();
        let ret = vector::empty<PasskeyInfoForView>();
        user_passkey_address_list.for_each(|addr| {
            let passkey_info = user_passkeys.infos.borrow(addr);
            let public_key = from_bcs::to_address(passkey_info.public_key);
            ret.push_back(PasskeyInfoForView{
                domain: passkey_info.domain,
                passkey_id: passkey_info.passkey_id,
                extra_data: passkey_info.extra_data,
                public_key
            });
        });
        ret
    }

    #[event]
    struct VerifyPassedEvent has store, drop, copy {

    }

    // for testing
    public entry fun passkey_verify<T: drop>(user: &signer, passkey: &signer) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        let passkey_address = signer::address_of(passkey);
        let user_passkeys = borrow_global<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.contains(passkey_address), EPASSKEY_NOT_CONTAINED);
        let _passkey_info = user_passkeys.infos.borrow(passkey_address);
        event::emit(VerifyPassedEvent{});
    }

    // return user's passkey object address by calculating with a fixed seed phrase.
    // reminder that this function will return a address whether the object is exists or not.
    fun get_user_passkey_object_address(user_address: address): address {
        object::create_object_address(&user_address, SEED)
    }

    fun assert_extra_data_length(extra_data: &vector<u8>) {
        assert!(vector::length(extra_data) < EXTRA_DATA_MAX_LENGTH, EEXTRA_DATA_TOO_LONG);
    }
}