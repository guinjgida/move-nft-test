module alcove_nft::creat_nft{
    use std::signer;
    use aptos_framework::account;
    use aptos_token_objects::collection;
    use aptos_token_objects::collection::MutatorRef;
    use std::string;
    use std::string::utf8;
    use std::option;
    use std::object;
    use aptos_framework::event;
    use aptos_std::string_utils;
    use aptos_framework::delegation_pool::enable_partial_governance_voting;
    use aptos_framework::object::{Object, object_address};
    use aptos_token_objects::token;

    use std::debug;

    const TokenPrefix: vector<u8> = b"alcopr #";

    const ResourceAccountSeed: vector<u8> = b"alcopr";
    const ERROR_OWNER:u64 = 1;

    const CollectionDescription: vector<u8> = b"This is a practice collection of alcove";

    const CollectionName: vector<u8> = b"alcopr";

    const CollectionURI: vector<u8> = b"https://bafybeicheiysxqzyt275h3z5msmo5e3fulfim7jjxniuer6yrnmnkok2e4.ipfs.nftstorage.link/ipfs/bafybeifjzs7wlhh74sn27l3egmz3mfmp5inrwctpdbtqzhlbritn34g46u?filename=";

    const TokenURI: vector<u8> = b"https://bafybeicheiysxqzyt275h3z5msmo5e3fulfim7jjxniuer6yrnmnkok2e4.ipfs.nftstorage.link/ipfs/bafybeifjzs7wlhh74sn27l3egmz3mfmp5inrwctpdbtqzhlbritn34g46u?filename=";

    struct TokenRefsStore has key {
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
        extend_ref: object::ExtendRef,
        transfer_ref: object::TransferRef
    }

    #[event]
    struct SetContentEvent has drop, store {
        owner: address,
        token_id: address,
        old_content: string::String,
        new_content: string::String
    }

    #[event]
    struct BurnEvent has drop, store {
        owner: address,
        token_id: address,
        content: string::String
    }

    #[event]
    struct MintEvent has drop, store {
        owner: address,
        token_id: address,
        content: string::String
    }

    #[event]
    struct TransferEvent has drop,store{
        owner:address,
        token_id:address,
        new_owner:address
    }

    struct ResourceCap has key {
        cap: account::SignerCapability
    }

    struct CollectionRefsStore has key {
        mutator_ref: MutatorRef
    }

    struct Content has key {
        content: string::String
    }

    fun init_module(sender:&signer){
        let(resource_signer,resocure_cap) = account::create_resource_account(
            sender,
            ResourceAccountSeed
        );

        move_to(
            &resource_signer,
            ResourceCap{
                cap:resocure_cap
            }
        );



        let collection_cref = collection::create_fixed_collection(
            &resource_signer,
            string::utf8(CollectionDescription),
            20,
            string::utf8(CollectionName),
            option::none(),
            string::utf8(CollectionURI)
        );

        let collection_signer = object::generate_signer(&collection_cref);

        let mutator_ref = collection::generate_mutator_ref(&collection_cref);

        move_to(
            &collection_signer,
            CollectionRefsStore{
                mutator_ref
            }
        );
    }


    entry public fun mint(
        sender:&signer,
        content:string::String
    )acquires ResourceCap {
        let resource_cap = &borrow_global<ResourceCap>(
            account::create_resource_address(
                &@alcove_nft,
                ResourceAccountSeed
            )
        ).cap;

        let resource_signer = &account::create_signer_with_capability(resource_cap);

        let url = string::utf8(TokenURI);

        let token_cref = token::create_numbered_token(
            resource_signer,
            string::utf8(CollectionName),
            string::utf8(CollectionDescription),
            string::utf8(TokenPrefix),
            string::utf8(b""),
            option::none(),
            string::utf8(b""),
        );

        let id = token::index<token::Token>(object::object_from_constructor_ref(&token_cref));
        string::append(&mut url,string_utils::to_string(&id));
        string::append(&mut url,string::utf8(b".jpg"));

        let token_signer = object::generate_signer(&token_cref);
        let token_mutator_ref = token::generate_mutator_ref(&token_cref);

        token::set_uri(&token_mutator_ref,url);

        let token_burn_ref = token::generate_burn_ref(&token_cref);

        let token_transfer_ref = object::generate_transfer_ref(&token_cref);


        let token_extend_ref = object::generate_extend_ref(&token_cref);

        move_to(
            &token_signer,
            TokenRefsStore{
                mutator_ref:token_mutator_ref,
                burn_ref:token_burn_ref,
                extend_ref:token_extend_ref,
                transfer_ref:token_transfer_ref
            }


        );

        move_to(&token_signer,Content{content});

        event::emit(
            MintEvent{
                owner:signer::address_of(sender),
                token_id:object::address_from_constructor_ref(&token_cref),
                content
            }
        );

        object::transfer(
            resource_signer,
            object::object_from_constructor_ref<token::Token>(&token_cref),
            signer::address_of(sender),
        );


    }


    entry fun burn(
        sender:&signer,
        object:Object<Content>
    ) acquires TokenRefsStore,Content{
        assert!(object::is_owner(object,signer::address_of(sender)),ERROR_OWNER);
        let TokenRefsStore{
            mutator_ref:_,
            burn_ref,
            extend_ref:i,
            transfer_ref:o
        } = move_from<TokenRefsStore>(object::object_address(&object));

        let Content{
            content
        } = move_from<Content>(object_address(&object));

        event::emit(
            BurnEvent{
                owner:object::owner(object),
                token_id:object::object_address(&object),
                content
            }
        );

        token::burn(burn_ref);
    }

    entry fun transfer(
        sender:&signer,
        object:Object<Content>,
        addr:address
    ){
        assert!(object::is_owner(object,signer::address_of(sender)),ERROR_OWNER);

        event::emit(
            TransferEvent{
                owner:object::owner(object),
                token_id:object::object_address(&object),
                new_owner:addr
            }
        );
        object::transfer(sender,object,addr);
    }

    inline fun borrow_content(owner: address, object: Object<Content>): &Content {
        assert!(object::is_owner(object, owner), ERROR_OWNER);
        borrow_global<Content>(object::object_address(&object))
    }

    inline fun borrow_mut_content(owner: address, object: Object<Content>): &mut Content {
        assert!(object::is_owner(object, owner), ERROR_OWNER);
        borrow_global_mut<Content>(object::object_address(&object))
    }

    entry fun set_content(
        sender:&signer,
        object:Object<Content>,
        content:string::String
    ) acquires Content{
        let old_content = borrow_content(signer::address_of(sender),object).content;
        event::emit(
            SetContentEvent{
                owner:object::owner(object),
                token_id:object::object_address(&object),
                old_content,
                new_content:content
            }
        );
        borrow_mut_content(signer::address_of(sender),object).content = content;

    }



    #[view]
    public fun get_content(object: Object<Content>): string::String acquires Content {
        borrow_global<Content>(object::object_address(&object)).content
    }


    #[test_only]
    public fun init_for_test(sender: &signer) {
        init_module(sender);

    }

}
