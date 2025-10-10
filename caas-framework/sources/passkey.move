module caas_framework::passkey {

    use std::vector;
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::event;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::object::{Self, ExtendRef};
    use caas_framework::namespace::{Self, NamespaceCore};
    use caas_framework::label;
    use caas_framework::witness::{Witness};

    struct PasskeyManagement has key {
        extend_ref: ExtendRef
    }

    struct UserPasskey<phantom ProjectType> has key {
        infos: SmartTable<address, PasskeyInfo>,
    }

    struct PasskeyInfo has store, copy, drop {
        public_key: vector<u8>, 
    }

    struct PasskeyInfoForView has store, copy, drop {
        passkey_address: address,
        public_key: vector<u8>
    }

    #[event]
    struct PasskeyInitializedEvent<phantom T> has store, copy, drop {
        user_address: address,
        project_signer_address: address,
        added_passkey_address: address,
        added_passkey_public_key: String
    }

    #[event]
    struct PasskeyRegisteredEvent<phantom T> has store, copy, drop {
        user_address: address,
        project_signer_address: address,
        added_passkey_address: address,
        added_passkey_public_key: String,
        authentication_passkey: address
    }

    #[event]
    struct PasskeyRemovedEvent<phantom T> has store, copy, drop {
        user_address: address,
        project_signer_address: address,
        removed_passkey_address: address,
        authentication_passkey: address,
    }

    const EALREADY_REGISTERED: u64 = 1;
    const ENO_PASSKEY_REGISTERED: u64 = 2;
    const EPASSKEY_NOT_CONTAINED: u64 = 3;
    const EPASSKEY_NOT_VALID: u64 = 4;
    const EPASSKEY_NOT_INITIALIZED: u64 = 5;
    const EPASSKEY_NOT_FOUND: u64 = 6;
    const EEXTRA_DATA_TOO_LONG: u64 = 7;
    const EHEX_STRING_LENGTH_INVALID: u64 = 8;
    const EPUBLIC_KEY_LENGTH_INVALID: u64 = 9;
    const EHEX_INVALID: u64 = 10;
    const EHEX_TO_U8_NEED_ONE_HEX: u64 = 11;
    const EPROJECT_SIGNER_NOT_APPROVED: u64 = 12;
    const ENOT_FIRST_INITIALIZE: u64 = 13;
    const EPROJECT_MUST_INITIALIZE_NAMESPACE_FIRST: u64 = 14;
    const EPASSKEYS_EXCEED_CAPACITY: u64 = 15;

    const PASSKEY_VERIFY_LABEL: vector<u8> = b"PASSKEY_VERIFY_SIGNER";
    const PASSKEY_USER_LABEL: vector<u8> = b"PASSKEY_USER";
    const SEED: vector<u8> = b"CAAS-PASSKEY";
    const EXTRA_DATA_MAX_LENGTH: u64 = 500;
    const USER_PASSKEY_MAX_LENGTH: u64 = 10;


    public entry fun initialize<T: drop>(
        user: &signer, 
        project_signer: &signer,
        passkey_address: address, 
        public_key: String,
    ) acquires PasskeyManagement, UserPasskey {
        // TODO: check out whether project has been registered in caas
        let user_address = signer::address_of(user);
        let project_signer_address = signer::address_of(project_signer);
        assert_project_signer<T>(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
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
        assert!(user_passkeys.infos.keys().length() == 0, ENOT_FIRST_INITIALIZE);
        assert!(!user_passkeys.infos.contains(passkey_address), EALREADY_REGISTERED);
        user_passkeys.infos.add(passkey_address, PasskeyInfo{
            public_key: hex_string_to_public_key(public_key),
        });
        label_user_passkey<T>(passkey_address);
        event::emit(PasskeyInitializedEvent<T>{
            user_address,
            added_passkey_address: passkey_address,
            project_signer_address,
            added_passkey_public_key: public_key
        });
    }

    public entry fun register_when_exists<T: drop>(
        user: &signer, 
        passkey_signer: &signer, 
        project_signer: &signer,
        passkey_address: address,
        public_key: String,
    ) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_signer_address = signer::address_of(passkey_signer);
        let project_signer_address = signer::address_of(project_signer);
        assert_project_signer<T>(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert!(object::object_exists<UserPasskey<T>>(passkey_object_address), EPASSKEY_NOT_INITIALIZED);
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.length() <= USER_PASSKEY_MAX_LENGTH, EPASSKEYS_EXCEED_CAPACITY);
        assert!(user_passkeys.infos.contains(passkey_signer_address), EPASSKEY_NOT_VALID);
        user_passkeys.infos.add(passkey_address, PasskeyInfo{
            public_key: hex_string_to_public_key(public_key),
        });
        label_user_passkey<T>(passkey_address);
        event::emit(PasskeyRegisteredEvent<T>{
            user_address,
            project_signer_address,
            added_passkey_address: passkey_address,
            added_passkey_public_key: public_key,
            authentication_passkey: passkey_signer_address
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
        let project_signer_address = signer::address_of(project_signer);
        assert_project_signer<T>(project_signer);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        assert!(object::object_exists<UserPasskey<T>>(passkey_object_address), EPASSKEY_NOT_INITIALIZED);
        let user_passkeys = borrow_global_mut<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.contains(passkey_signer_address), EPASSKEY_NOT_VALID);
        assert!(user_passkeys.infos.contains(to_remove), EPASSKEY_NOT_FOUND);
        let _passkey_info = user_passkeys.infos.remove(to_remove);
        remove_user_passkey_label<T>(to_remove);
        event::emit(PasskeyRemovedEvent<T>{
            user_address,
            project_signer_address,
            removed_passkey_address: to_remove,
            authentication_passkey: passkey_signer_address
        });
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
            ret.push_back(PasskeyInfoForView{
                passkey_address: addr,
                public_key: passkey_info.public_key
            });
        });
        ret
    }

    #[event]
    struct VerifyPassedEvent has store, drop, copy {

    }

    public entry fun passkey_verify<T: drop>(
        user: &signer, 
        passkey: &signer, 
        project_signer: &signer
    ) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_object_address = get_user_passkey_object_address(user_address);
        let passkey_address = signer::address_of(passkey);
        let user_passkeys = borrow_global<UserPasskey<T>>(passkey_object_address);
        assert!(user_passkeys.infos.contains(passkey_address), EPASSKEY_NOT_CONTAINED);
        assert_project_signer<T>(project_signer);
        let _passkey_info = user_passkeys.infos.borrow(passkey_address);
        event::emit(VerifyPassedEvent{});
    }

    // Project signer need to be verified by project's label system, to be simplified, the label data must 
    // contain the signer address as a passkey verify signer, if the project label data does not set the passkey
    // signer address, it will fallback to use the caas framework default signer to check with.
    fun assert_project_signer<T: drop>(project_signer: &signer) {
        let project_signer_address = signer::address_of(project_signer);
        let primary_namespace_address = namespace::get_primary_namespace_address<T>();
        let primary_namespace = object::address_to_object<NamespaceCore>(primary_namespace_address);
        assert!(label::does_label_initialized_internal<T>(primary_namespace), EPROJECT_MUST_INITIALIZE_NAMESPACE_FIRST);
        if(
            label::has_label_enum_internal<T>(primary_namespace, string::utf8(PASSKEY_VERIFY_LABEL))
        ) {
            assert!(
                label::has_label_internal<T>(
                    primary_namespace, 
                    project_signer_address, 
                    string::utf8(PASSKEY_VERIFY_LABEL)
                ),
                EPROJECT_SIGNER_NOT_APPROVED
            );
        } else {
            let caas_framework_namespace_address = namespace::get_primary_namespace_address<Witness>();
            let caas_framework_namespace = object::address_to_object<NamespaceCore>(caas_framework_namespace_address);
            assert!(
                label::has_label_internal<Witness>(
                    caas_framework_namespace,
                    project_signer_address,
                    string::utf8(PASSKEY_VERIFY_LABEL)
                ),
                EPROJECT_SIGNER_NOT_APPROVED
            )
        };
    }

    fun label_user_passkey<T: drop>(user_passkey_address: address) {
        let primary_namespace_address = namespace::get_primary_namespace_address<T>();
        let primary_namespace = object::address_to_object<NamespaceCore>(primary_namespace_address);
        if(!label::has_label_enum_internal<T>(primary_namespace, string::utf8(PASSKEY_USER_LABEL))) {
            label::add_enums_internal<T>(primary_namespace, string::utf8(PASSKEY_USER_LABEL));
        };
        label::set_label_internal<T>(primary_namespace, user_passkey_address, string::utf8(PASSKEY_USER_LABEL));
    }

    fun remove_user_passkey_label<T: drop>(user_passkey_address: address) {
        let primary_namespace_address = namespace::get_primary_namespace_address<T>();
        let primary_namespace = object::address_to_object<NamespaceCore>(primary_namespace_address);
        label::remove_label_internal<T>(primary_namespace, user_passkey_address, string::utf8(PASSKEY_USER_LABEL));

    }

    // return user's passkey object address by calculating with a fixed seed phrase.
    // reminder that this function will return a address whether the object is exists or not.
    fun get_user_passkey_object_address(user_address: address): address {
        object::create_object_address(&user_address, SEED)
    }

    fun hex_string_to_public_key(hex_string: String): vector<u8> {
        let length = hex_string.length();
        assert!(length % 2 == 0, EHEX_STRING_LENGTH_INVALID);
        // trim the '0x' padding term
        if(hex_string.sub_string(0, 2) == string::utf8(b"0x")) {
            hex_string = hex_string.sub_string(2, length);
        };
        assert!(hex_string.length() == 130, EPUBLIC_KEY_LENGTH_INVALID);
        let public_key = vector::empty<u8>();
        let i = 0;
        while(i < 65) {
            let start_index = i * 2;
            let bytes_hex_string = hex_string.sub_string(start_index, start_index + 2);
            let bytes = hex_to_bytes(bytes_hex_string);
            public_key.push_back(bytes);
            i += 1;
        };
        // public_key.reverse();
        public_key
    }

    fun hex_to_bytes(hex_string: String): u8 {
        let first_hex = hex_string.sub_string(0, 1);
        let first_hex_to_u8 = hex_to_u8(first_hex); 
        let first_hex_to_u8 = first_hex_to_u8 << 4;
        let second_hex = hex_string.sub_string(1, 2);
        let second_hex_to_u8 = hex_to_u8(second_hex); 
        first_hex_to_u8 + second_hex_to_u8
    }

    inline fun hex_to_u8(hex_string: String): u8 {
        assert!(hex_string.length() == 1, EHEX_TO_U8_NEED_ONE_HEX);
        let ret = if(hex_string == string::utf8(b"0")) {
            0x0
        } else if(hex_string == string::utf8(b"1")) {
            0x1
        } else if(hex_string == string::utf8(b"2")) {
            0x2
        } else if(hex_string == string::utf8(b"3")) {
            0x3
        } else if(hex_string == string::utf8(b"4")) {
            0x4
        } else if(hex_string == string::utf8(b"5")) {
            0x5
        } else if(hex_string == string::utf8(b"6")) {
            0x6
        } else if(hex_string == string::utf8(b"7")) {
            0x7
        } else if(hex_string == string::utf8(b"8")) {
            0x8
        } else if(hex_string == string::utf8(b"9")) {
            0x9
        } else if(hex_string == string::utf8(b"a")) {
            0xa
        } else if(hex_string == string::utf8(b"b")) {
            0xb
        } else if(hex_string == string::utf8(b"c")) {
            0xc
        } else if(hex_string == string::utf8(b"d")) {
            0xd
        } else if(hex_string == string::utf8(b"e")) {
            0xe
        } else if(hex_string == string::utf8(b"f")) {
            0xf
        } else {
            abort(EHEX_INVALID);
            0xff
        };
        ret
    } 

}