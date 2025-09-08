module caas_framework::passkey {

    use std::vector;
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::account;
    use std::string::{String};
    use aptos_std::smart_table::{Self, SmartTable};

    struct UserPasskey has key {
        infos: SmartTable<address, PasskeyInfo>,
        active: bool
    }

    struct PasskeyInfo has store, copy {
        domain: String,
        active: bool,
        passkey_id: String,
        tag: String
    }

    struct PasskeyInfoForView has store, copy, drop {
        domain: String,
        active: bool,
        passkey_id: String,
        tag: String,
        pubkey: vector<u8>
    }

    const EALREADY_REGISTERED: u64 = 1;
    const ENO_PASSKEY_REGISTERED: u64 = 2;
    const EPASSKEY_NOT_CONTAINED: u64 = 3;
    const EPASSKEY_NOT_ACTIVED: u64 = 4;

    public entry fun register(
        user: &signer, 
        passkey_signer: &signer, 
        passkey_id: String, 
        tag: String, 
        domain: String
    ) acquires UserPasskey {
        let user_address = signer::address_of(user);
        if(!exists<UserPasskey>(user_address)) {
            move_to(user, UserPasskey{
                infos: smart_table::new<address, PasskeyInfo>(),
                active: true
            });
        };
        let user_passkeys = borrow_global_mut<UserPasskey>(user_address);
        let passkey_signer_address = signer::address_of(passkey_signer);
        assert!(user_passkeys.infos.contains(passkey_signer_address), EALREADY_REGISTERED);
        user_passkeys.infos.add(passkey_signer_address, PasskeyInfo{
            domain,
            tag,
            passkey_id,
            active: true
        });
        // TODO: event
    }

    #[view]
    public fun is_user_registered(): bool {
        false
    }

    #[view]
    public fun is_user_passkey_activated(): bool {
        false
    }

    #[view]
    public fun user_passkey_list(user_address: address): vector<PasskeyInfoForView> acquires UserPasskey {
        assert!(exists<UserPasskey>(user_address), ENO_PASSKEY_REGISTERED);
        let user_passkeys = borrow_global_mut<UserPasskey>(user_address);
        let user_passkey_address_list = user_passkeys.infos.keys();
        let ret = vector::empty<PasskeyInfoForView>();
        user_passkey_address_list.for_each(|addr| {
            let pubkey = account::get_authentication_key(addr);
            let passkey_info = user_passkeys.infos.borrow(addr);
            ret.push_back(PasskeyInfoForView{
                domain: passkey_info.domain,
                active: passkey_info.active,
                passkey_id: passkey_info.passkey_id,
                tag: passkey_info.tag,
                pubkey
            });
        });
        ret
    }

    #[event]
    struct VerifyPassedEvent has store, drop, copy {

    }

    // for testing
    public entry fun sig_verify(user: &signer, passkey: &signer) acquires UserPasskey {
        let user_address = signer::address_of(user);
        let passkey_address = signer::address_of(passkey);
        let user_passkeys = borrow_global<UserPasskey>(user_address);
        assert!(user_passkeys.infos.contains(passkey_address), EPASSKEY_NOT_CONTAINED);
        let passkey_info = user_passkeys.infos.borrow(passkey_address);
        assert!(passkey_info.active, EPASSKEY_NOT_ACTIVED);
        event::emit(VerifyPassedEvent{});
    }

}