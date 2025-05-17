"""
Aptos Indexer Integration for AptosSybilShield

This module handles integration with the Aptos Indexer API for retrieving
blockchain data, specifically configured for Aptos devnet.
"""

import os
import logging
import requests
import json
import time
from typing import Dict, List, Any, Optional
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport

# Import configuration
from config.ml_config import APTOS_DEVNET_URL, APTOS_INDEXER_URL, CONTRACT_ADDRESS, INDEXER_CONFIG

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("indexer_integration")

class AptosIndexerClient:
    """
    Client for interacting with the Aptos Indexer API on devnet.
    
    This class provides methods to query transaction data, account information,
    and other blockchain metrics from the Aptos Indexer.
    """
    
    def __init__(self):
        """Initialize the Aptos Indexer client for devnet."""
        self.indexer_url = APTOS_INDEXER_URL
        self.aptos_url = APTOS_DEVNET_URL
        self.contract_address = CONTRACT_ADDRESS
        self.sync_interval = INDEXER_CONFIG["sync_interval_seconds"]
        self.max_retries = INDEXER_CONFIG["max_retries"]
        self.timeout = INDEXER_CONFIG["timeout_seconds"]
        self.batch_size = INDEXER_CONFIG["batch_size"]
        
        # Set up GraphQL client for indexer
        transport = RequestsHTTPTransport(
            url=self.indexer_url,
            verify=True,
            retries=self.max_retries,
            timeout=self.timeout
        )
        self.client = Client(transport=transport, fetch_schema_from_transport=True)
        
        logger.info(f"Initialized Aptos Indexer client for devnet: {self.indexer_url}")
        if not self.contract_address:
            logger.warning("Contract address not set. Some queries may not work correctly.")
    
    def get_account_transactions(self, address: str, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get transactions for a specific account from the indexer.
        
        Args:
            address: The account address
            limit: Maximum number of transactions to retrieve
            
        Returns:
            List of transaction objects
        """
        logger.info(f"Getting transactions for account {address}")
        
        # GraphQL query for account transactions
        query = gql("""
        query AccountTransactions($address: String!, $limit: Int!) {
          account_transactions(
            where: {account_address: {_eq: $address}}
            limit: $limit
            order_by: {timestamp: desc}
          ) {
            transaction_version
            transaction_hash
            sender
            receiver
            timestamp
            type
            status
            gas_used
            gas_unit_price
          }
        }
        """)
        
        try:
            # Execute the query
            result = self.client.execute(
                query,
                variable_values={"address": address, "limit": limit}
            )
            
            transactions = result.get("account_transactions", [])
            logger.info(f"Retrieved {len(transactions)} transactions for account {address}")
            
            return transactions
        except Exception as e:
            logger.error(f"Error retrieving transactions for account {address}: {e}")
            return []
    
    def get_transaction_by_hash(self, tx_hash: str) -> Optional[Dict[str, Any]]:
        """
        Get transaction details by hash.
        
        Args:
            tx_hash: The transaction hash
            
        Returns:
            Transaction object or None if not found
        """
        logger.info(f"Getting transaction by hash {tx_hash}")
        
        # GraphQL query for transaction by hash
        query = gql("""
        query TransactionByHash($hash: String!) {
          transactions(where: {hash: {_eq: $hash}}) {
            transaction_version
            transaction_hash
            sender
            timestamp
            type
            status
            gas_used
            gas_unit_price
            events {
              type
              data
            }
          }
        }
        """)
        
        try:
            # Execute the query
            result = self.client.execute(
                query,
                variable_values={"hash": tx_hash}
            )
            
            transactions = result.get("transactions", [])
            if transactions:
                logger.info(f"Retrieved transaction {tx_hash}")
                return transactions[0]
            else:
                logger.warning(f"Transaction {tx_hash} not found")
                return None
        except Exception as e:
            logger.error(f"Error retrieving transaction {tx_hash}: {e}")
            return None
    
    def get_account_resources(self, address: str) -> List[Dict[str, Any]]:
        """
        Get resources for a specific account.
        
        Args:
            address: The account address
            
        Returns:
            List of resource objects
        """
        logger.info(f"Getting resources for account {address}")
        
        # Use REST API for resources since GraphQL might not have all resource types
        url = f"{self.aptos_url}/accounts/{address}/resources"
        
        try:
            response = requests.get(url, timeout=self.timeout)
            response.raise_for_status()
            
            resources = response.json()
            logger.info(f"Retrieved {len(resources)} resources for account {address}")
            
            return resources
        except Exception as e:
            logger.error(f"Error retrieving resources for account {address}: {e}")
            return []
    
    def get_contract_events(self, event_handle: str, field_name: str, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get events from a specific event handle.
        
        Args:
            event_handle: The event handle address
            field_name: The field name of the event handle
            limit: Maximum number of events to retrieve
            
        Returns:
            List of event objects
        """
        logger.info(f"Getting events for handle {event_handle}.{field_name}")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve events.")
            return []
        
        # Use REST API for events
        url = f"{self.aptos_url}/accounts/{self.contract_address}/events/{event_handle}/{field_name}"
        params = {"limit": limit}
        
        try:
            response = requests.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            
            events = response.json()
            logger.info(f"Retrieved {len(events)} events for handle {event_handle}.{field_name}")
            
            return events
        except Exception as e:
            logger.error(f"Error retrieving events for handle {event_handle}.{field_name}: {e}")
            return []
    
    def get_sybil_detection_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get Sybil detection events from the contract.
        
        Args:
            limit: Maximum number of events to retrieve
            
        Returns:
            List of Sybil detection event objects
        """
        logger.info("Getting Sybil detection events")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve Sybil detection events.")
            return []
        
        # Event handle for Sybil detection events
        event_handle = f"{self.contract_address}::sybil_detection::SybilEventHandle"
        field_name = "detection_events"
        
        return self.get_contract_events(event_handle, field_name, limit)
    
    def get_verification_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get identity verification events from the contract.
        
        Args:
            limit: Maximum number of events to retrieve
            
        Returns:
            List of verification event objects
        """
        logger.info("Getting verification events")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve verification events.")
            return []
        
        # Event handle for verification events
        event_handle = f"{self.contract_address}::identity_verification::VerificationEventHandle"
        field_name = "verification_events"
        
        return self.get_contract_events(event_handle, field_name, limit)
    
    def get_reputation_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get reputation scoring events from the contract.
        
        Args:
            limit: Maximum number of events to retrieve
            
        Returns:
            List of reputation event objects
        """
        logger.info("Getting reputation events")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve reputation events.")
            return []
        
        # Event handle for reputation events
        event_handle = f"{self.contract_address}::reputation_scoring::ReputationEventHandle"
        field_name = "reputation_events"
        
        return self.get_contract_events(event_handle, field_name, limit)
    
    def get_indexer_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get indexer integration events from the contract.
        
        Args:
            limit: Maximum number of events to retrieve
            
        Returns:
            List of indexer event objects
        """
        logger.info("Getting indexer events")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve indexer events.")
            return []
        
        # Event handle for indexer events
        event_handle = f"{self.contract_address}::indexer_integration::IndexerEventHandle"
        field_name = "indexer_events"
        
        return self.get_contract_events(event_handle, field_name, limit)
    
    def get_feature_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get feature extraction events from the contract.
        
        Args:
            limit: Maximum number of events to retrieve
            
        Returns:
            List of feature event objects
        """
        logger.info("Getting feature events")
        
        if not self.contract_address:
            logger.error("Contract address not set. Cannot retrieve feature events.")
            return []
        
        # Event handle for feature events
        event_handle = f"{self.contract_address}::feature_extraction::FeatureEventHandle"
        field_name = "feature_events"
        
        return self.get_contract_events(event_handle, field_name, limit)
    
    def sync_data(self) -> bool:
        """
        Sync data from the indexer.
        
        Returns:
            True if sync was successful, False otherwise
        """
        logger.info("Syncing data from indexer")
        
        try:
            # Get latest events from all modules
            sybil_events = self.get_sybil_detection_events()
            verification_events = self.get_verification_events()
            reputation_events = self.get_reputation_events()
            indexer_events = self.get_indexer_events()
            feature_events = self.get_feature_events()
            
            # Process events (in a real implementation, this would update local state)
            logger.info(f"Synced {len(sybil_events)} sybil events, "
                       f"{len(verification_events)} verification events, "
                       f"{len(reputation_events)} reputation events, "
                       f"{len(indexer_events)} indexer events, "
                       f"{len(feature_events)} feature events")
            
            return True
        except Exception as e:
            logger.error(f"Error syncing data from indexer: {e}")
            return False
    
    def update_contract_address(self, address: str) -> bool:
        """
        Update the contract address.
        
        Args:
            address: The new contract address
            
        Returns:
            True if update was successful, False otherwise
        """
        logger.info(f"Updating contract address to {address}")
        
        try:
            self.contract_address = address
            
            # Test connection with new address
            resources = self.get_account_resources(address)
            if resources:
                logger.info(f"Successfully updated contract address to {address}")
                return True
            else:
                logger.warning(f"Updated contract address to {address}, but no resources found")
                return False
        except Exception as e:
            logger.error(f"Error updating contract address to {address}: {e}")
            return False


if __name__ == "__main__":
    # Example usage
    indexer_client = AptosIndexerClient()
    
    # If contract address is set, sync data
    if indexer_client.contract_address:
        indexer_client.sync_data()
    else:
        logger.warning("Contract address not set. Please set it before syncing data.")
        
        # For testing purposes, use a sample address
        sample_address = "0x1"
        transactions = indexer_client.get_account_transactions(sample_address)
        print(f"Retrieved {len(transactions)} transactions for sample account {sample_address}")
