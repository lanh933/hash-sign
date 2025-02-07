module HashSign::hash_sign2 {
    use std::string::String;
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_std::simple_map::{Self, SimpleMap};

    struct Document has store, drop, copy {
        id: u64,
        content_hash: String,
        creator: address,
        signers: vector<address>,
        signatures: vector<Signature>,
        is_completed: bool,
    }

    struct Signature has store, drop, copy {
        signer: address,
        timestamp: u64,
    }

    struct GlobalDocumentStore has key {
        documents: SimpleMap<u64, Document>,
        document_counter: u64,
    }

    struct EventStore has key {
        create_document_events: event::EventHandle<CreateDocumentEvent>,
        sign_document_events: event::EventHandle<SignDocumentEvent>,
    }

    struct CreateDocumentEvent has drop, store {
        document_id: u64,
        creator: address,
    }

    struct SignDocumentEvent has drop, store {
        document_id: u64,
        signer: address,
    }

    // Initialize the GlobalDocumentStore and EventStore
    fun init_module(account: &signer) {
        move_to(account, GlobalDocumentStore {
            documents: simple_map::create(),
            document_counter: 0,
        });
        move_to(account, EventStore {
            create_document_events: account::new_event_handle<CreateDocumentEvent>(account),
            sign_document_events: account::new_event_handle<SignDocumentEvent>(account),
        });
    }

    // Create a new document
    public entry fun create_document(creator: &signer, content_hash: String, signers: vector<address>) acquires GlobalDocumentStore, EventStore {
        let creator_address = std::signer::address_of(creator);
        let store = borrow_global_mut<GlobalDocumentStore>(@HashSign);
        let event_store = borrow_global_mut<EventStore>(@HashSign);
        
        let document = Document {
            id: store.document_counter,
            content_hash,
            creator: creator_address,
            signers,
            signatures: vector::empty(),
            is_completed: false,
        };

        simple_map::add(&mut store.documents, store.document_counter, document);
        
        event::emit_event(&mut event_store.create_document_events, CreateDocumentEvent {
            document_id: store.document_counter,
            creator: creator_address,
        });

        store.document_counter = store.document_counter + 1;
    }

    // Sign a document
    public entry fun sign_document(signer: &signer, document_id: u64) acquires GlobalDocumentStore, EventStore {
        let signer_address = std::signer::address_of(signer);
        let store = borrow_global_mut<GlobalDocumentStore>(@HashSign);
        let event_store = borrow_global_mut<EventStore>(@HashSign);
        
        assert!(simple_map::contains_key(&store.documents, &document_id), 3); // Ensure document exists

        let document = simple_map::borrow_mut(&mut store.documents, &document_id);
        assert!(!document.is_completed, 1); // Document is not yet completed
        assert!(vector::contains(&document.signers, &signer_address), 2); // Signer is authorized

        let signature = Signature {
            signer: signer_address,
            timestamp: timestamp::now_microseconds(),
        };

        vector::push_back(&mut document.signatures, signature);

        event::emit_event(&mut event_store.sign_document_events, SignDocumentEvent {
            document_id,
            signer: signer_address,
        });

        // Check if all signers have signed
        if (vector::length(&document.signatures) == vector::length(&document.signers)) {
            document.is_completed = true;
        }
    }

    // Get document details
    #[view]
    public fun get_document(document_id: u64): Document acquires GlobalDocumentStore {
        let store = borrow_global<GlobalDocumentStore>(@HashSign);
        assert!(simple_map::contains_key(&store.documents, &document_id), 4); // Ensure document exists
        *simple_map::borrow(&store.documents, &document_id)
    }

    // Get all documents
    #[view]
    public fun get_all_documents(): vector<Document> acquires GlobalDocumentStore {
        let store = borrow_global<GlobalDocumentStore>(@HashSign);
        let all_documents = vector::empty<Document>();
        let i = 0;
        while (i < store.document_counter) {
            if (simple_map::contains_key(&store.documents, &i)) {
                vector::push_back(&mut all_documents, *simple_map::borrow(&store.documents, &i));
            };
            i = i + 1;
        };
        all_documents
    }

    // Get total number of documents
    #[view]
    public fun get_total_documents(): u64 acquires GlobalDocumentStore {
        let store = borrow_global<GlobalDocumentStore>(@HashSign);
        store.document_counter
    }
}