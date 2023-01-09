// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
	uint256 public maxAllowedOptions;
	mapping(address => bool) public whitelistedItemAddresses;

	/**
	 * @dev Storing proposal data inside a mapping
	 */
	mapping(string => Entity.Proposal) public proposals;

	/**
	 * @dev Configure swap registry
	 * @param _maxAllowedItems: maximum amount of allowed items
	 * @param _maxAllowedOptions: maximum amount of allowed options
	 * @param _whitelistedItemAddresses: whitelisted addresses
	 * @param _blackListedItemAddresses: blacklisted addresses
	 */
	function configure(
		uint256 _maxAllowedItems,
		uint256 _maxAllowedOptions,
		address[] memory _whitelistedItemAddresses,
		address[] memory _blackListedItemAddresses
	) external onlyOwner whenNotPaused {
		/**
		 * @dev Configure values
		 */
		maxAllowedItems = _maxAllowedItems;
		maxAllowedOptions = _maxAllowedOptions;

		/**
		 * @dev Whitelisting addresses
		 */
		for (uint256 i = 0; i < _whitelistedItemAddresses.length; i++) {
			whitelistedItemAddresses[_whitelistedItemAddresses[i]] = true;
		}

		/**
		 * @dev Blacklisted addresses
		 */
		for (uint256 i = 0; i < _blackListedItemAddresses.length; i++) {
			whitelistedItemAddresses[_blackListedItemAddresses[i]] = false;
		}
	}

	/**
	 * @dev Create proposal and deposit items
	 * @param id: proposal id
	 * @param swapItemsData: swap item list to be passed into proposal creation
	 * @param swapOptionsData: swap option list to be passed into proposal creation
	 * @param expiredAt: expiry date of the proposal
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
		 * @dev Require constraints
		 */
		assert(swapOptionsData.length <= maxAllowedOptions);
		assert(swapItemsData.length <= maxAllowedItems);

		/**
		 * @dev Assign proposal
		 */
		proposals[id].id = id;
		proposals[id].expiredAt = expiredAt;
		proposals[id].status = Entity.ProposalStatus.Deposited;
		proposals[id].owner = msg.sender;

		/**
		 * @dev Aggregate swap option data
		 */
		for (uint256 i = 0; i < swapOptionsData.length; i++) {
			for (
				uint256 j = 0;
				j < swapOptionsData[i].askingItems.length;
				j++
			) {
				proposals[id].swapOptions[i].askingItems[j] = swapOptionsData[i]
					.askingItems[j];
			}
		}

		/**
		 * @dev Deposit items and adjust data properly
		 */
		for (uint256 i = 0; i < swapItemsData.length; i++) {
			/**
			 * @dev Must be a whitelisted addresses
			 */
			assert(
				whitelistedItemAddresses[swapItemsData[i].contractAddress] ==
					true
			);

			/**
			 * @dev Initialize empty struct
			 */
			Entity.SwapItem memory swapItem;

			/**
			 * @dev Assign data
			 */
			swapItem.id = swapItemsData[i].id;
			swapItem.contractAddress = swapItemsData[i].contractAddress;
			swapItem.itemType = swapItemsData[i].itemType;
			swapItem.owner = msg.sender;
			swapItem.status = Entity.SwapItemStatus.Deposited;
			swapItem.tokenId = swapItemsData[i].tokenId;
			swapItem.amount = swapItemsData[i].amount;

			/**
			 * @dev Deposit ERC721 assets
			 */
			if (swapItem.itemType == Entity.SwapItemType.Nft) {
				swapItem.amount = 1;

				/**
				 * @dev Deposit
				 */
				IERC721(swapItem.contractAddress).safeTransferFrom(
					msg.sender,
					address(this),
					swapItem.tokenId
				);
			}

			/**
			 * @dev Deposit ERC20 assets
			 */
			if (swapItem.itemType == Entity.SwapItemType.Currency) {
				/**
				 * @dev Deposit
				 */
				assert(
					IERC20(swapItem.contractAddress).transferFrom(
						msg.sender,
						address(this),
						swapItem.amount
					)
				);
			}

			/**
			 * @dev Now we push into the array
			 */
			proposals[id].offeredItems.push(swapItem);
		}
	}

	/**
	 * @dev Fulfill proposal
	 * @param proposalId: the proposal id that targeted to
	 * @param optionId: the option id that user wants to fulfil with
	 */
	function fulfillProposal(string memory proposalId, string memory optionId)
		external
		whenNotPaused
	{
		/**
		 * @dev Must be an existed proposal
		 */
		assert(bytes(proposals[proposalId].id).length > 0);

		/**
		 * @dev The proposal must be at deposited phase.
		 */
		assert(proposals[proposalId].status == Entity.ProposalStatus.Deposited);

		/**
		 * @dev The proposal must be still in time window.
		 */
		assert(proposals[proposalId].expiredAt <= block.timestamp);

		/**
		 * @dev Adjust proposal value.
		 */
		proposals[proposalId].fulfilledBy = msg.sender;
		proposals[proposalId].fulfilledByOptionId = optionId;

		/**
		 * @dev Find the proposal
		 */
		uint256 index = maxAllowedItems + 1;

		for (uint256 i = 0; i < proposals[proposalId].swapOptions.length; i++) {
			Entity.Proposal memory _proposal = proposals[proposalId];
			Entity.SwapOption memory _option = _proposal.swapOptions[i];
			string memory _optionId = _option.id;

			if (areStringsEqual(_optionId, optionId)) {
				index = i;
				break;
			}
		}

		/**
		 * @dev Check for constraints
		 */
		assert(index != maxAllowedItems + 1);

		/**
		 * @dev Binding option
		 */
		Entity.SwapOption memory option = proposals[proposalId].swapOptions[
			index
		];

		/**
		 * @dev Check for constraints
		 */
		assert(bytes(proposals[proposalId].swapOptions[index].id).length > 0);
		assert(option.askingItems.length <= maxAllowedItems);

		/**
		 * @dev Deposit required items
		 */
		for (uint256 i = 0; i < option.askingItems.length; i++) {
			/**
			 * @dev Must be a whitelisted addresses
			 */
			assert(
				whitelistedItemAddresses[
					option.askingItems[i].contractAddress
				] == true
			);

			/**
			 * @dev Change to deposited
			 */
			option.askingItems[i].status = Entity.SwapItemStatus.Deposited;

			/**
			 * @dev Deposit ERC721 assets
			 */
			if (option.askingItems[i].itemType == Entity.SwapItemType.Nft) {
				/**
				 * @dev Deposit
				 */
				IERC721(option.askingItems[i].contractAddress).safeTransferFrom(
						msg.sender,
						address(this),
						option.askingItems[i].tokenId
					);
			}

			/**
			 * @dev Deposit ERC20 assets
			 */
			if (
				option.askingItems[i].itemType == Entity.SwapItemType.Currency
			) {
				/**
				 * @dev Deposit
				 */
				assert(
					IERC20(option.askingItems[i].contractAddress).transferFrom(
						msg.sender,
						address(this),
						option.askingItems[i].amount
					)
				);
			}
		}
	}

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

	function areStringsEqual(string memory s1, string memory s2)
		private
		pure
		returns (bool)
	{
		return
			keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
	}
}
