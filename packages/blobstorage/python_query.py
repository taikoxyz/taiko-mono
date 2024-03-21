import mysql.connector

def query_blob_hash(collection_name, blob_hash):

    # Connect to MySQL
    connection = mysql.connector.connect(
        host='localhost',
        user='root',  # Update with your username
        password='passw00d',  # Update with your password
        database='blobs'  # Update with your database name
    )

    cursor = connection.cursor(dictionary=True)

    # Query the table for the blobHash
    query = f"SELECT * FROM blob_hashes WHERE blob_hash = %s"
    cursor.execute(query, (blob_hash,))

    # Fetch one result
    result = cursor.fetchone()

    # Close the cursor and connection
    cursor.close()
    connection.close()

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
