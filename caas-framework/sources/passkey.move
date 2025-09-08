module caas_framework::passkey {

    struct UserPassKey has key {
        infos: SmartTable<address, PassKeyInfo>,
        active: bool
    }

    struct PassKeyInfo has store, copy {
        domain: String,
        active: bool
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
    public fun user_passkey_list: vector<PassKeyInfo> {
        vector::empty<PassKeyInfo>()
    }


}