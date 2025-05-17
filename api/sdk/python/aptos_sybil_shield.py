"""
AptosSybilShield Python SDK for Aptos devnet

This module provides a Python SDK for interacting with the AptosSybilShield
contract deployed on Aptos devnet.
"""

import os
import logging
import requests
import json
import time
from typing import Dict, List, Any, Optional, Union, Tuple
from aptos_sdk.account import Account
from aptos_sdk.client import RestClient
from aptos_sdk.transactions import EntryFunction, TransactionArgument
from aptos_sdk.type_tag import TypeTag, StructTag

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("aptos_sybil_shield")

class AptosSybilShield:
    """
    Python SDK for interacting with the AptosSybilShield contract on Aptos devnet.
    
    This class provides methods to interact with all modules of the AptosSybilShield
    contract, including sybil detection, identity verification, reputation scoring,
    indexer integration, and feature extraction.
    """
    
    def __init__(
        self, 
        node_url: str = "https://fullnode.devnet.aptoslabs.com/v1",
        contract_address: Optional[str] = None,
        private_key: Optional[str] = None
    ):
        """
        Initialize the AptosSybilShield SDK.
        
        Args:
            node_url: URL of the Aptos node (defaults to devnet)
            contract_address: Address of the deployed AptosSybilShield contract
            private_key: Private key for transaction signing (hex string without 0x prefix)
        """
        self.node_url = node_url
        self.contract_address = contract_address
        self.rest_client = RestClient(node_url)
        
        # Set up account if private key is provided
        self.account = None
        if private_key:
            self.account = Account.load_key(private_key)
            logger.info(f"Initialized account: {self.account.address()}")
        
        logger.info(f"Initialized AptosSybilShield SDK with node URL: {node_url}")
        if contract_address:
            logger.info(f"Contract address: {contract_address}")
        else:
            logger.warning("Contract address not set. Please set it before making contract calls.")
    
    def set_contract_address(self, address: str) -> None:
        """
        Set the contract address.
        
        Args:
            address: The contract address
        """
        self.contract_address = address
        logger.info(f"Set contract address to: {address}")
    
    def set_account(self, private_key: str) -> None:
        """
        Set the account for transaction signing.
        
        Args:
            private_key: Private key (hex string without 0x prefix)
        """
        self.account = Account.load_key(private_key)
        logger.info(f"Set account: {self.account.address()}")
    
    def _check_setup(self) -> bool:
        """
        Check if the SDK is properly set up.
        
        Returns:
            True if setup is complete, False otherwise
        """
        if not self.contract_address:
            logger.error("Contract address not set")
            return False
        
        if not self.account:
            logger.error("Account not set")
            return False
        
        return True
    
    def _submit_transaction(
        self, 
        function_name: str, 
        type_args: List[TypeTag] = None,
        args: List[TransactionArgument] = None
    ) -> str:
        """
        Submit a transaction to the contract.
        
        Args:
            function_name: Name of the function to call
            type_args: Type arguments
            args: Function arguments
            
        Returns:
            Transaction hash
        """
        if not self._check_setup():
            raise ValueError("SDK not properly set up")
        
        if type_args is None:
            type_args = []
        
        if args is None:
            args = []
        
        # Create entry function
        entry_function = EntryFunction.natural(
            f"{self.contract_address}",
            function_name,
            type_args,
            args
        )
        
        # Submit transaction
        tx_hash = self.rest_client.submit_transaction(self.account, entry_function)
        logger.info(f"Submitted transaction: {tx_hash}")
        
        # Wait for transaction to complete
        self.rest_client.wait_for_transaction(tx_hash)
        logger.info(f"Transaction completed: {tx_hash}")
        
        return tx_hash
    
    def _query_view_function(
        self, 
        function_name: str, 
        type_args: List[TypeTag] = None,
        args: List[Any] = None
    ) -> Any:
        """
        Query a view function on the contract.
        
        Args:
            function_name: Name of the function to call
            type_args: Type arguments
            args: Function arguments
            
        Returns:
            Function result
        """
        if not self.contract_address:
            raise ValueError("Contract address not set")
        
        if type_args is None:
            type_args = []
        
        if args is None:
            args = []
        
        # Query view function
        result = self.rest_client.view_function(
            self.contract_address,
            function_name,
            type_args,
            args
        )
        
        return result
    
    # Sybil Detection Module Functions
    
    def register_address_for_sybil_detection(self) -> str:
        """
        Register the current account for Sybil detection.
        
        Returns:
            Transaction hash
        """
        return self._submit_transaction("sybil_detection::register_address")
    
    def update_risk_threshold(self, threshold: int) -> str:
        """
        Update the risk threshold for Sybil detection.
        
        Args:
            threshold: New threshold value (0-100)
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "sybil_detection::update_risk_threshold",
            args=[TransactionArgument(threshold, Serializer.u64)]
        )
    
    def set_verification_required(self, required: bool) -> str:
        """
        Set whether verification is required for Sybil detection.
        
        Args:
            required: Whether verification is required
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "sybil_detection::set_verification_required",
            args=[TransactionArgument(required, Serializer.bool)]
        )
    
    def update_risk_score(
        self, 
        target_addr: str, 
        new_score: int, 
        factor_type: int, 
        factor_score: int, 
        factor_confidence: int
    ) -> str:
        """
        Update the risk score for an address.
        
        Args:
            target_addr: Target address
            new_score: New overall risk score (0-100)
            factor_type: Factor type (1-4)
            factor_score: Factor score (0-100)
            factor_confidence: Factor confidence (0-100)
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "sybil_detection::update_risk_score",
            args=[
                TransactionArgument(target_addr, Serializer.address),
                TransactionArgument(new_score, Serializer.u64),
                TransactionArgument(factor_type, Serializer.u8),
                TransactionArgument(factor_score, Serializer.u64),
                TransactionArgument(factor_confidence, Serializer.u64)
            ]
        )
    
    def get_risk_score(self, addr: str) -> int:
        """
        Get the risk score for an address.
        
        Args:
            addr: Target address
            
        Returns:
            Risk score (0-100)
        """
        result = self._query_view_function(
            "sybil_detection::get_risk_score",
            args=[addr]
        )
        return result[0]
    
    def is_flagged(self, addr: str) -> bool:
        """
        Check if an address is flagged as potential Sybil.
        
        Args:
            addr: Target address
            
        Returns:
            True if flagged, False otherwise
        """
        result = self._query_view_function(
            "sybil_detection::is_flagged",
            args=[addr]
        )
        return result[0]
    
    def is_verification_required(self) -> bool:
        """
        Check if verification is required for Sybil detection.
        
        Returns:
            True if required, False otherwise
        """
        result = self._query_view_function(
            "sybil_detection::is_verification_required"
        )
        return result[0]
    
    # Identity Verification Module Functions
    
    def request_verification(self, verification_type: int, verification_data: bytes) -> str:
        """
        Request identity verification.
        
        Args:
            verification_type: Type of verification (1-4)
            verification_data: Verification data
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "identity_verification::request_verification",
            args=[
                TransactionArgument(verification_type, Serializer.u8),
                TransactionArgument(verification_data, Serializer.bytes)
            ]
        )
    
    def verify_identity(self, target_addr: str, verification_result: bool, proof: bytes) -> str:
        """
        Verify an identity.
        
        Args:
            target_addr: Target address
            verification_result: Verification result
            proof: Verification proof
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "identity_verification::verify_identity",
            args=[
                TransactionArgument(target_addr, Serializer.address),
                TransactionArgument(verification_result, Serializer.bool),
                TransactionArgument(proof, Serializer.bytes)
            ]
        )
    
    def is_verified(self, addr: str) -> bool:
        """
        Check if an address is verified.
        
        Args:
            addr: Target address
            
        Returns:
            True if verified, False otherwise
        """
        result = self._query_view_function(
            "identity_verification::is_verified",
            args=[addr]
        )
        return result[0]
    
    def get_verification_status(self, addr: str) -> int:
        """
        Get verification status for an address.
        
        Args:
            addr: Target address
            
        Returns:
            Verification status (0-4)
        """
        result = self._query_view_function(
            "identity_verification::get_verification_status",
            args=[addr]
        )
        return result[0]
    
    # Reputation Scoring Module Functions
    
    def register_address_for_reputation(self) -> str:
        """
        Register the current account for reputation scoring.
        
        Returns:
            Transaction hash
        """
        return self._submit_transaction("reputation_scoring::register_address")
    
    def update_category_score(
        self, 
        target_addr: str, 
        category: int, 
        new_score: int, 
        reason: bytes
    ) -> str:
        """
        Update the reputation score for a category.
        
        Args:
            target_addr: Target address
            category: Category (1-6)
            new_score: New score (0-100)
            reason: Reason for update
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "reputation_scoring::update_category_score",
            args=[
                TransactionArgument(target_addr, Serializer.address),
                TransactionArgument(category, Serializer.u8),
                TransactionArgument(new_score, Serializer.u64),
                TransactionArgument(reason, Serializer.bytes)
            ]
        )
    
    def get_overall_score(self, addr: str) -> int:
        """
        Get the overall reputation score for an address.
        
        Args:
            addr: Target address
            
        Returns:
            Overall score (0-100)
        """
        result = self._query_view_function(
            "reputation_scoring::get_overall_score",
            args=[addr]
        )
        return result[0]
    
    def get_category_score(self, addr: str, category: int) -> int:
        """
        Get the reputation score for a specific category.
        
        Args:
            addr: Target address
            category: Category (1-6)
            
        Returns:
            Category score (0-100)
        """
        result = self._query_view_function(
            "reputation_scoring::get_category_score",
            args=[addr, category]
        )
        return result[0]
    
    def meets_minimum_threshold(self, addr: str, threshold: int) -> bool:
        """
        Check if an address meets the minimum reputation threshold.
        
        Args:
            addr: Target address
            threshold: Threshold value (0-100)
            
        Returns:
            True if meets threshold, False otherwise
        """
        result = self._query_view_function(
            "reputation_scoring::meets_minimum_threshold",
            args=[addr, threshold]
        )
        return result[0]
    
    # Feature Extraction Module Functions
    
    def update_feature(
        self, 
        target_addr: str, 
        feature_type: int, 
        feature_name: str, 
        feature_value: int
    ) -> str:
        """
        Update a feature for an address.
        
        Args:
            target_addr: Target address
            feature_type: Feature type (1-4)
            feature_name: Feature name
            feature_value: Feature value
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "feature_extraction::update_feature",
            args=[
                TransactionArgument(target_addr, Serializer.address),
                TransactionArgument(feature_type, Serializer.u8),
                TransactionArgument(feature_name, Serializer.string),
                TransactionArgument(feature_value, Serializer.u64)
            ]
        )
    
    def get_feature_value(self, addr: str, feature_type: int, feature_name: str) -> int:
        """
        Get a feature value for an address.
        
        Args:
            addr: Target address
            feature_type: Feature type (1-4)
            feature_name: Feature name
            
        Returns:
            Feature value
        """
        result = self._query_view_function(
            "feature_extraction::get_feature_value",
            args=[addr, feature_type, feature_name]
        )
        return result[0]
    
    # Indexer Integration Module Functions
    
    def register_indexer(
        self, 
        indexer_type: int, 
        name: str, 
        url: str, 
        api_key: bytes, 
        data_format_version: int
    ) -> str:
        """
        Register an indexer.
        
        Args:
            indexer_type: Indexer type (1-4)
            name: Indexer name
            url: Indexer URL
            api_key: API key
            data_format_version: Data format version
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "indexer_integration::register_indexer",
            args=[
                TransactionArgument(indexer_type, Serializer.u8),
                TransactionArgument(name, Serializer.string),
                TransactionArgument(url, Serializer.string),
                TransactionArgument(api_key, Serializer.bytes),
                TransactionArgument(data_format_version, Serializer.u8)
            ]
        )
    
    def submit_data(
        self, 
        data_type: int, 
        data_hash: bytes, 
        target_addresses: List[str]
    ) -> str:
        """
        Submit data from an indexer.
        
        Args:
            data_type: Data type (1-4)
            data_hash: Data hash
            target_addresses: List of target addresses
            
        Returns:
            Transaction hash
        """
        return self._submit_transaction(
            "indexer_integration::submit_data",
            args=[
                TransactionArgument(data_type, Serializer.u8),
                TransactionArgument(data_hash, Serializer.bytes),
                TransactionArgument(target_addresses, Serializer.sequence_of_address)
            ]
        )
    
    def is_indexer_active(self, indexer_addr: str) -> bool:
        """
        Check if an indexer is active.
        
        Args:
            indexer_addr: Indexer address
            
        Returns:
            True if active, False otherwise
        """
        result = self._query_view_function(
            "indexer_integration::is_indexer_active",
            args=[indexer_addr]
        )
        return result[0]
    
    def get_submission_stats(self, indexer_addr: str) -> Tuple[int, int, int, int, int]:
        """
        Get submission statistics for an indexer.
        
        Args:
            indexer_addr: Indexer address
            
        Returns:
            Tuple of (submission_count, last_submission, processed_addresses, 
                     successful_submissions, failed_submissions)
        """
        result = self._query_view_function(
            "indexer_integration::get_submission_stats",
            args=[indexer_addr]
        )
        return tuple(result)


# Helper class for serialization
class Serializer:
    """Helper class for serializing transaction arguments."""
    
    @staticmethod
    def u8(value: int) -> bytes:
        """Serialize u8."""
        return value.to_bytes(1, byteorder="little")
    
    @staticmethod
    def u64(value: int) -> bytes:
        """Serialize u64."""
        return value.to_bytes(8, byteorder="little")
    
    @staticmethod
    def bool(value: bool) -> bytes:
        """Serialize bool."""
        return bytes([1 if value else 0])
    
    @staticmethod
    def address(value: str) -> bytes:
        """Serialize address."""
        if value.startswith("0x"):
            value = value[2:]
        return bytes.fromhex(value)
    
    @staticmethod
    def bytes(value: bytes) -> bytes:
        """Serialize bytes."""
        return value
    
    @staticmethod
    def string(value: str) -> bytes:
        """Serialize string."""
        return value.encode("utf-8")
    
    @staticmethod
    def sequence_of_address(addresses: List[str]) -> bytes:
        """Serialize sequence of addresses."""
        result = len(addresses).to_bytes(4, byteorder="little")
        for addr in addresses:
            result += Serializer.address(addr)
        return result


if __name__ == "__main__":
    # Example usage
    sdk = AptosSybilShield()
    
    # Set contract address and account (these would be provided by the user)
    # sdk.set_contract_address("0x123...")
    # sdk.set_account("private_key_hex")
    
    # Example: If contract address and account are set, register for Sybil detection
    # tx_hash = sdk.register_address_for_sybil_detection()
    # print(f"Registered for Sybil detection: {tx_hash}")
