// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Entity.sol";

/**
 * @notice HamsterSwap which is a trustless p2p exchange,
 * handles NFT-NFT, NFT-Currency and Currency-Currency swap transactions.
 **/
/// @custom:security-contact khang@cavies.xyz
contract HamsterSwap is Initializable, PausableUpgradeable, OwnableUpgradeable {
	/**
	 * @dev Administration configurations
	 */
	uint256 public maxAllowedItems;
	mapping(address => bool) public whitelistedItemAddresses;

	/**
	 * @dev Storing proposal data inside a mapping
	 */
	mapping(string => Entity.Proposal) public proposals;

	/**
	 * @dev Configure swap registry
	 */
	function configure(
		uint256 _maxAllowedItems,
		address[] memory _whitelistedItemAddresses
	) external onlyOwner whenNotPaused {}

	/**
	 * @dev Create proposal and deposit items
	 */
	function createProposal(
		string memory id,
		Entity.SwapItem[] memory swapItemsData,
		Entity.SwapOption[] memory swapOptionsData,
		uint256 expiredAt
	) external whenNotPaused {
		/**
		 * @dev Avoid duplicated proposal id to be recorded in.
		 */
		assert(bytes(proposals[id].id).length == 0);

		/**
		 * @dev Assign proposal
		 */
		proposals[id].id = id;
		proposals[id].expiredAt = expiredAt;

		/**
		 * @dev Deposit items and adjust data properly
		 */
		for (uint256 i = 0; i < swapItemsData.length; i++) {
			/**
			 * @dev Initialize empty struct
			 */
			Entity.SwapItem memory swapItem;

			/**
			 * @dev Assign data
			 */
			swapItem.id = swapItemsData[i].id;
			swapItem.amount = swapItemsData[i].amount;
			swapItem.contractAddress = swapItemsData[i].contractAddress;
			swapItem.itemType = swapItemsData[i].itemType;
			swapItem.owner = msg.sender;
			swapItem.status = Entity.SwapItemStatus.Deposited;

			/**
			 * @dev Transfer assets to contract
			 */

			/**
			 * @dev Now we push into the array
			 */
			proposals[id].offeredItems.push(swapItem);
		}
	}

	function fulfillProposal(string memory proposalId, string memory optionId)
		external
		whenNotPaused
	{}

	function cancelProposal(string memory proposalId) external whenNotPaused {}

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize() public initializer {
		__Pausable_init();
		__Ownable_init();
	}

	function pause() public onlyOwner {
		_pause();
	}

	function unpause() public onlyOwner {
		_unpause();
	}
}
