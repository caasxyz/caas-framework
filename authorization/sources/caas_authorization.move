module caas::identity_verification {

    use std::string::{String};
    use aptos_std::smart_table::{SmartTable};
    /// Project information
    struct ProjectInfo has store, copy, drop {
        /// Project identifier
        project_name: String,
        /// Project object address
        project_object_address: address,
        /// Authorizer address
        authorizer: address
    }

    /// Project information
    /// Inter-project authorization registry
    struct AuthorizationRegistry has key {
        /// Authorized address -> Authorization information
        /// One authorized address can only correspond to one authorization relationship
        authorizations: SmartTable<address, vector<AuthorizationInfo>>,

        /// Authorizer -> List of authorized parties (for easy query)
        authorizer_to_authorized: SmartTable<address, vector<AuthorizationInfo>>,

        /// Authorized party -> List of authorizers (for easy query)
        authorized_to_authorizers: SmartTable<address, vector<AuthorizationInfo>>,

        /// Authorized project -> Set of projects with permission
        project_authorizes: SmartTable<ProjectInfo, vector<address>>
    }

    /// Project configuration (stored under the project object address)
    struct ProjectConfig has key {
        /// Project owner address
        owner: address,
        /// Project creation time
        created_at: u64
        /// Other project configurations...
    }

    /// Authorization details
    struct AuthorizationInfo has store, copy, drop {
        /// Project information
        project: ProjectInfo,

        /// Authorized party address
        authorized: address,

        /// Authorization creation time
        created_at: u64,

        /// Expiration time (0 means never expires)
        expires_at: u64,

        /// Whether enabled
        is_active: bool,

        /// Read permission
        read: bool,

        /// Write permission (temporarily not enabled, always false)
        write: bool
    }

    public fun verify_authentication<T: drop>(
        project_to_fetch: address, witness: T
    ): bool {
        // verify witness
        // then verify authentication
    }
}

