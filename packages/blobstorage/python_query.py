from pymongo import MongoClient

def query_blob_hash(collection_name, blob_hash):
    # Connect to MongoDB
    client = MongoClient('localhost', 27017)

    # Access the database
    db = client['blob_storage']

    # Access the collection
    collection = db[collection_name]

    # Query the collection for the blobHash
    result = collection.find_one({'blob_hash': blob_hash})

    # Close the connection
    client.close()

    return result

def main():
    collection_name = 'blobs'
    blob_hash = '0x01a2a1cdc7ad221934061642a79a760776a013d0e6fa1a1c6b642ace009c372a'

    result = query_blob_hash(collection_name, blob_hash)
    if result:
        print('Found result:', result)
    else:
        print('Blob hash not found')

if __name__ == '__main__':
    main()
