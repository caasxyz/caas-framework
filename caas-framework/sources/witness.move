module caas_framework::witness {
    // This is a util module for caas_framework self-witness and resources defining. 
    use std::option;
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use caas_framework::label;
    use caas_framework::identity;
    use caas_framework::namespace::{Self, NamespaceCore};

    struct Witness has drop {}

    const ENOT_ADMIN: u64 = 1;

    public entry fun create_identity(admin: &signer) {
        assert!(signer::address_of(admin) == @caas_admin, ENOT_ADMIN);
        identity::register_identity<Witness>(admin, string::utf8(b"CAAS_FRAMEWORK"));
    }

    public entry fun create_namespace(admin: &signer) {
        assert!(signer::address_of(admin) == @caas_admin, ENOT_ADMIN);
        let witness = Witness{};
        let parent_obj = option::none<Object<NamespaceCore>>();
        let _ = namespace::create_namespace<Witness>(witness, parent_obj);
    }

    public entry fun create_label(admin: &signer) {
        assert!(signer::address_of(admin) == @caas_admin, ENOT_ADMIN);
        let namespace_address = namespace::get_primary_namespace_address<Witness>();
        let namespace = object::address_to_object<NamespaceCore>(namespace_address);
        label::create(namespace, Witness{});
        label::add_enums(namespace, string::utf8(b"PASSKEY_VERIFY_SIGNER"), Witness{});
        label::set_label(namespace, @caas_framework, string::utf8(b"PASSKEY_VERIFY_SIGNER"), Witness{});
    }

    public entry fun set_label(admin: &signer, address_to_label: address, label: String) {
        assert!(signer::address_of(admin) == @caas_admin, ENOT_ADMIN);
        let namespace_address = namespace::get_primary_namespace_address<Witness>();
        let namespace = object::address_to_object<NamespaceCore>(namespace_address);
        label::set_label(namespace, address_to_label, label, Witness{});
    }

}