"""
Decentralized Storage System for AptosSybilShield

This module implements decentralized storage solutions for sensitive data,
ensuring privacy and security while maintaining accessibility.
"""

import os
import logging
import hashlib
import json
import time
import base64
from typing import Dict, List, Tuple, Any, Optional
from datetime import datetime
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("decentralized_storage")

class DecentralizedStorage:
    """
    Decentralized storage system for sensitive user data.
    
    This implementation provides a simplified decentralized storage system for the hackathon.
    In a production environment, this would integrate with IPFS, Filecoin, Arweave, or similar.
    """
    
    def __init__(self, storage_dir: str = None):
        """
        Initialize the decentralized storage system.
        
        Args:
            storage_dir: Directory for storing data (for simulation purposes)
        """
        self.storage_dir = storage_dir or os.path.join(os.path.dirname(__file__), "data")
        os.makedirs(self.storage_dir, exist_ok=True)
        
        # In-memory index for demonstration purposes
        # In a real implementation, this would be distributed or on-chain
        self.data_index = {}
        
    def store_data(self, data: Any, encryption_key: str = None, metadata: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Store data in decentralized storage.
        
        Args:
            data: Data to store
            encryption_key: Optional encryption key
            metadata: Optional metadata
            
        Returns:
            Storage receipt with CID and access info
        """
        # Convert data to JSON string if it's not already a string
        if not isinstance(data, str):
            data_str = json.dumps(data)
        else:
            data_str = data
            
        # Generate a unique content identifier (CID)
        data_hash = hashlib.sha256(data_str.encode()).hexdigest()
        timestamp = int(time.time())
        cid = f"aptos-sybil-{data_hash[:12]}-{timestamp}"
        
        # Encrypt data if encryption key is provided
        if encryption_key:
            # In a real implementation, this would use proper encryption
            # For hackathon purposes, we'll use a simple XOR-based approach
            encrypted_data = self._simple_encrypt(data_str, encryption_key)
            is_encrypted = True
        else:
            encrypted_data = data_str
            is_encrypted = False
            
        # Create storage object
        storage_object = {
            "cid": cid,
            "data": encrypted_data,
            "is_encrypted": is_encrypted,
            "created_at": datetime.now().isoformat(),
            "size": len(data_str),
            "metadata": metadata or {}
        }
        
        # Store in simulated decentralized storage
        filename = f"{cid}.json"
        filepath = os.path.join(self.storage_dir, filename)
        
        with open(filepath, 'w') as f:
            json.dump(storage_object, f)
            
        # Update index
        self.data_index[cid] = {
            "filepath": filepath,
            "is_encrypted": is_encrypted,
            "size": len(data_str),
            "created_at": storage_object["created_at"],
            "metadata": metadata or {}
        }
        
        # Return receipt
        return {
            "cid": cid,
            "timestamp": timestamp,
            "is_encrypted": is_encrypted,
            "size": len(data_str),
            "access_url": f"ds://{cid}"
        }
    
    def retrieve_data(self, cid: str, encryption_key: str = None) -> Dict[str, Any]:
        """
        Retrieve data from decentralized storage.
        
        Args:
            cid: Content identifier
            encryption_key: Encryption key if data is encrypted
            
        Returns:
            Retrieved data and metadata
        """
        if cid not in self.data_index:
            return {
                "success": False,
                "error": "Content not found"
            }
            
        index_entry = self.data_index[cid]
        filepath = index_entry["filepath"]
        
        try:
            with open(filepath, 'r') as f:
                storage_object = json.load(f)
                
            # Decrypt if necessary
            if storage_object["is_encrypted"]:
                if not encryption_key:
                    return {
                        "success": False,
                        "error": "Encryption key required"
                    }
                    
                try:
                    decrypted_data = self._simple_decrypt(storage_object["data"], encryption_key)
                    # Try to parse as JSON
                    try:
                        data = json.loads(decrypted_data)
                    except json.JSONDecodeError:
                        data = decrypted_data
                except Exception as e:
                    return {
                        "success": False,
                        "error": f"Decryption failed: {str(e)}"
                    }
            else:
                # Try to parse as JSON
                try:
                    data = json.loads(storage_object["data"])
                except json.JSONDecodeError:
                    data = storage_object["data"]
                    
            return {
                "success": True,
                "cid": cid,
                "data": data,
                "metadata": storage_object["metadata"],
                "created_at": storage_object["created_at"],
                "is_encrypted": storage_object["is_encrypted"]
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Retrieval failed: {str(e)}"
            }
    
    def delete_data(self, cid: str) -> Dict[str, Any]:
        """
        Delete data from decentralized storage.
        
        Args:
            cid: Content identifier
            
        Returns:
            Deletion result
        """
        if cid not in self.data_index:
            return {
                "success": False,
                "error": "Content not found"
            }
            
        index_entry = self.data_index[cid]
        filepath = index_entry["filepath"]
        
        try:
            os.remove(filepath)
            del self.data_index[cid]
            
            return {
                "success": True,
                "cid": cid,
                "deleted_at": datetime.now().isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Deletion failed: {str(e)}"
            }
    
    def list_data(self, metadata_filter: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """
        List data in decentralized storage.
        
        Args:
            metadata_filter: Optional filter for metadata
            
        Returns:
            List of data entries
        """
        results = []
        
        for cid, entry in self.data_index.items():
            # Apply metadata filter if provided
            if metadata_filter:
                match = True
                for key, value in metadata_filter.items():
                    if key not in entry["metadata"] or entry["metadata"][key] != value:
                        match = False
                        break
                        
                if not match:
                    continue
                    
            results.append({
                "cid": cid,
                "size": entry["size"],
                "created_at": entry["created_at"],
                "is_encrypted": entry["is_encrypted"],
                "metadata": entry["metadata"]
            })
            
        return results
    
    def _simple_encrypt(self, data: str, key: str) -> str:
        """
        Simple encryption for demonstration purposes.
        
        Args:
            data: Data to encrypt
            key: Encryption key
            
        Returns:
            Encrypted data
        """
        # Create a key hash
        key_hash = hashlib.sha256(key.encode()).digest()
        
        # Convert data to bytes
        data_bytes = data.encode()
        
        # XOR with key (repeating as needed)
        encrypted_bytes = bytearray()
        for i in range(len(data_bytes)):
            encrypted_bytes.append(data_bytes[i] ^ key_hash[i % len(key_hash)])
            
        # Return as base64
        return base64.b64encode(encrypted_bytes).decode()
    
    def _simple_decrypt(self, encrypted_data: str, key: str) -> str:
        """
        Simple decryption for demonstration purposes.
        
        Args:
            encrypted_data: Encrypted data
            key: Encryption key
            
        Returns:
            Decrypted data
        """
        # Create a key hash
        key_hash = hashlib.sha256(key.encode()).digest()
        
        # Convert from base64
        encrypted_bytes = base64.b64decode(encrypted_data)
        
        # XOR with key (repeating as needed)
        decrypted_bytes = bytearray()
        for i in range(len(encrypted_bytes)):
            decrypted_bytes.append(encrypted_bytes[i] ^ key_hash[i % len(key_hash)])
            
        # Return as string
        return decrypted_bytes.decode()


class SensitiveDataManager:
    """
    Manager for handling sensitive user data with decentralized storage.
    """
    
    def __init__(self, storage: DecentralizedStorage):
        """
        Initialize the sensitive data manager.
        
        Args:
            storage: Decentralized storage system
        """
        self.storage = storage
        
    def store_verification_data(self, user_id: str, verification_type: str, 
                               data: Dict[str, Any], encrypt: bool = True) -> Dict[str, Any]:
        """
        Store verification data securely.
        
        Args:
            user_id: User identifier
            verification_type: Type of verification
            data: Verification data
            encrypt: Whether to encrypt the data
            
        Returns:
            Storage receipt
        """
        # Generate metadata
        metadata = {
            "user_id": user_id,
            "verification_type": verification_type,
            "content_type": "verification_data",
            "timestamp": datetime.now().isoformat()
        }
        
        # Generate encryption key if needed
        encryption_key = None
        if encrypt:
            encryption_key = f"{user_id}:{uuid.uuid4().hex}"
            
        # Store data
        receipt = self.storage.store_data(
            data=data,
            encryption_key=encryption_key,
            metadata=metadata
        )
        
        # Add encryption key to receipt if used
        if encrypt:
            receipt["encryption_key"] = encryption_key
            
        return receipt
    
    def store_identity_proof(self, user_id: str, proof_type: str, 
                           proof_data: Dict[str, Any], encrypt: bool = True) -> Dict[str, Any]:
        """
        Store identity proof securely.
        
        Args:
            user_id: User identifier
            proof_type: Type of proof
            proof_data: Proof data
            encrypt: Whether to encrypt the data
            
        Returns:
            Storage receipt
        """
        # Generate metadata
        metadata = {
            "user_id": user_id,
            "proof_type": proof_type,
            "content_type": "identity_proof",
            "timestamp": datetime.now().isoformat()
        }
        
        # Generate encryption key if needed
        encryption_key = None
        if encrypt:
            encryption_key = f"{user_id}:{uuid.uuid4().hex}"
            
        # Store data
        receipt = self.storage.store_data(
            data=proof_data,
            encryption_key=encryption_key,
            metadata=metadata
        )
        
        # Add encryption key to receipt if used
        if encrypt:
            receipt["encryption_key"] = encryption_key
            
        return receipt
    
    def retrieve_user_data(self, cid: str, encryption_key: str = None) -> Dict[str, Any]:
        """
        Retrieve user data securely.
        
        Args:
            cid: Content identifier
            encryption_key: Encryption key if data is encrypted
            
        Returns:
            Retrieved data
        """
        return self.storage.retrieve_data(cid, encryption_key)
    
    def list_user_data(self, user_id: str) -> List[Dict[str, Any]]:
        """
        List all data for a user.
        
        Args:
            user_id: User identifier
            
        Returns:
            List of data entries
        """
        return self.storage.list_data({"user_id": user_id})


if __name__ == "__main__":
    # Example usage
    storage = DecentralizedStorage()
    manager = SensitiveDataManager(storage)
    
    # Store verification data
    user_id = "user123"
    verification_data = {
        "name": "John Doe",
        "email": "john@example.com",
        "birth_date": "1990-01-01",
        "country": "USA",
        "verified_at": datetime.now().isoformat()
    }
    
    receipt = manager.store_verification_data(
        user_id=user_id,
        verification_type="kyc",
        data=verification_data,
        encrypt=True
    )
    
    print(f"Data stored with CID: {receipt['cid']}")
    print(f"Encryption key: {receipt.get('encryption_key')}")
    
    # Retrieve the data
    result = manager.retrieve_user_data(
        cid=receipt['cid'],
        encryption_key=receipt['encryption_key']
    )
    
    if result['success']:
        print(f"Retrieved data: {result['data']}")
    else:
        print(f"Retrieval failed: {result['error']}")
    
    # List user data
    user_data = manager.list_user_data(user_id)
    print(f"User data entries: {len(user_data)}")
    for entry in user_data:
        print(f"  - {entry['cid']} ({entry['metadata']['content_type']})")
