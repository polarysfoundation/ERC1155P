// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ERC1155P (ERC-1155Polarys)
 * @dev A standard ERC1155 contract with added metadata URI support.
 * @author Polarys Foundation (Uranus)
 */
contract ERC1155P is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;
    using Strings for uint256;

    struct TokenOwnership {
        address addr;
        bool burned;
        uint256 amount;
    }

    struct TokenData {
        address[] owners;
        mapping(address => bool) isOwner;
    }

    string internal _name;
    string internal _symbol;

    string internal _uri;

    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => mapping(address => TokenOwnership)) private _tokenOwners;
    mapping(uint256 => mapping(uint256 => address)) private _tokenApprovals;
    // Mapping to store token ownership for a given ID
    mapping(uint256 => TokenData) private _tokenData;

    /**
     * @dev Initializes the contract with a name, symbol, and base URI.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param uri_ The base URI for metadata.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_
    ) {
        _name = name_;
        _symbol = symbol_;
        _uri = uri_;
    }

    event Approval(address owner, address to, uint256 id, uint256 amount);

    /**
     * @dev Sets the approval status for an operator to operate on all tokens of the caller.
     * @param operator The address of the operator.
     * @param approved True if approval is granted, false otherwise.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev Approves an address to spend a specific amount of tokens.
     * @param to The address to approve for.
     * @param id The ID of the token.
     * @param amount The amount to approve.
     */
    function approve(address to, uint256 id, uint256 amount) public {
        address operator = _msgSender();
        bool isOwner = _checkOwnership(id, operator);
        uint256 ownerBalance = _tokenOwners[id][operator].amount;

        require(isOwner, "ERC1155: You are not the owner of this token");
        require(
            ownerBalance >= amount,
            "ERC1155: approve amount exceeds balance"
        );
        _approve(to, id, amount, operator);
    }

    /**
     * @dev Gets the approved address for a specific token ID and amount.
     * @param id The ID of the token.
     * @param amount The amount of the token.
     * @return The approved address.
     */
    function getApproved(
        uint256 id,
        uint256 amount
    ) public view returns (address) {
        require(id != 0, "ERC1155: id can't be zero");
        require(amount != 0, "ERC1155: amount can't be zero");
        return _tokenApprovals[id][amount];
    }

    /**
     * @dev Checks if an operator is approved for all tokens of an owner.
     * @param account The owner's address.
     * @param operator The operator's address.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Internal function to approve an address to spend a specific amount of tokens.
     * @param to The address to approve for.
     * @param id The ID of the token.
     * @param amount The amount to approve.
     * @param owner The owner of the tokens.
     */
    function _approve(
        address to,
        uint256 id,
        uint256 amount,
        address owner
    ) private {
        _tokenApprovals[id][amount] = to;
        emit Approval(owner, to, id, amount);
    }

    /**
     * @dev Gets the balance of a specific token for an address.
     * @param account The address to query the balance for.
     * @param id The ID of the token.
     * @return The balance of the token for the address.
     */
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual override returns (uint256) {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );

        return _tokenOwners[id][account].amount;
    }

    /**
     * @dev Gets the batch balances of multiple tokens for multiple addresses.
     * @param accounts The addresses to query balances for.
     * @param ids The IDs of the tokens.
     * @return An array of batch balances.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(
            ids.length == accounts.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev Returns the URI for a token ID.
     * @param id The ID of the token.
     * @return The token's metadata URI.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev Safely mints a specific amount of a token to an address.
     * @param to The address to mint tokens to.
     * @param id The ID of the token.
     * @param amount The amount of tokens to mint.
     */
    function _safeMint(address to, uint256 id, uint256 amount) internal {
        _safeMint(to, id, amount, "");
    }

    /**
     * @dev Safely mints a specific amount of a token to an address with additional data.
     * @param to The address to mint tokens to.
     * @param id The ID of the token.
     * @param amount The amount of tokens to mint.
     * @param data Additional data.
     */
    function _safeMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        _mint(to, id, amount, data, true);
    }

    /**
     * @dev Internal function to mint tokens.
     * @param account The address to mint tokens to.
     * @param id The ID of the token.
     * @param amount The amount of tokens to mint.
     * @param data Additional data.
     * @param safe Whether to perform a safe mint.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data,
        bool safe
    ) internal {
        address operator = _msgSender();

        require(account != address(0), "ERC1155: Minter can't be address(0)");
        require(amount != 0, "ERC1155: Amount can't be zero");

        _beforeTokenTransfer(
            operator,
            address(0),
            account,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );
        unchecked {
            if (safe) {
                TokenOwnership memory tokenOwners;
                tokenOwners.addr = account;
                tokenOwners.amount += amount;
                tokenOwners.burned = false;
                _tokenOwners[id][account] = tokenOwners;
                _addTokenOwner(id, account);
                emit TransferSingle(operator, address(0), account, id, amount);
            }
        }
    }

    /**
     * @dev Safely transfers a specific amount of a token from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param id The ID of the token.
     * @param amount The amount of tokens to transfer.
     * @param data Additional data.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Safely transfers multiple tokens from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param ids The IDs of the tokens to transfer.
     * @param amounts The amounts of tokens to transfer.
     * @param data Additional data.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Internal function to safely transfer tokens.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param id The ID of the token.
     * @param amount The amount of tokens to transfer.
     * @param data Additional data.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        address operator = _msgSender();
        require(
            from == operator || _operatorApprovals[from][operator],
            "ERC1155: caller is not owner nor approved"
        );

        _beforeTokenTransfer(
            operator,
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        require(
            amount <= _tokenOwners[id][from].amount,
            "ERC1155: You don't have enough tokens"
        );
        require(
            _tokenOwners[id][from].addr == from,
            "ERC1155: transfer of token that is not owned"
        );
        require(
            _tokenOwners[id][from].burned == false,
            "ERC1155: transfer of burned token"
        );

        _tokenOwners[id][from].amount -= amount;
        if (amount == _tokenOwners[id][from].amount) {
            _tokenOwners[id][from].burned = true;
            _removeTokenOwner(id, from);
        }
        _addTokenOwner(id, to);
        TokenOwnership memory tokenOwners;
        tokenOwners.addr = operator;
        tokenOwners.amount += amount;
        tokenOwners.burned = false;
        _tokenOwners[id][operator] = tokenOwners;
        emit TransferSingle(operator, from, to, id, amount);
    }

    /**
     * @dev Internal function to mint a batch of tokens.
     * @param to The address to mint tokens to.
     * @param ids The IDs of the tokens to mint.
     * @param amounts The amounts of tokens to mint.
     * @param data Additional data.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        address operator = _msgSender();
        require(to != address(0), "ERC1155: mint to the zero address");
        uint256 idsLength = ids.length;
        require(
            idsLength == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        for (uint256 i = 0; i < idsLength; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            _addTokenOwner(id, to);
            TokenOwnership memory tokenOwners;
            tokenOwners.addr = to;
            tokenOwners.amount += amount;
            tokenOwners.burned = false;
            _tokenOwners[id][to] = tokenOwners;
        }
        emit TransferBatch(operator, address(0), to, ids, amounts);
    }

    /**
     * @dev Internal function to safely transfer a batch of tokens.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param ids The IDs of the tokens to transfer.
     * @param amounts The amounts of tokens to transfer.
     * @param data Additional data.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        address operator = _msgSender();
        require(
            from == operator || _operatorApprovals[from][_msgSender()],
            "ERC1155: caller is not owner nor approved"
        );
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        uint256 idsLength = ids.length;
        require(
            idsLength == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        for (uint256 i = 0; i < idsLength; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            require(
                _tokenOwners[id][from].addr == from,
                "ERC1155: transfer of token that is not owned"
            );
            require(
                _tokenOwners[id][from].burned == false,
                "ERC1155: transfer of burned token"
            );
            _tokenOwners[id][from].amount -= amount;
            if (amount == _tokenOwners[id][from].amount) {
                _tokenOwners[id][from].burned = true;
                _removeTokenOwner(id, from);
            }
            _addTokenOwner(id, to);
            TokenOwnership memory tokenOwners;
            tokenOwners.addr = to;
            tokenOwners.amount += amount;
            tokenOwners.burned = false;
            _tokenOwners[id][to] = tokenOwners;
        }
        emit TransferBatch(operator, from, to, ids, amounts);
    }

    /**
     * @dev Sets a new URI for all token types.
     * @param newuri The new URI.
     */
    function _setURI(string memory newuri) internal {
        _uri = newuri;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens.
     * @param owner The owner address.
     * @param operator The operator address.
     * @param approved Whether the operator is approved or not.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`.
     * @param from The address to burn tokens from.
     * @param id The ID of the token to burn.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 id, uint256 amount) internal {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 fromBalance = _tokenOwners[id][from].amount;
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            if (amount == fromBalance) {
                _tokenOwners[id][from].burned = true;
                _removeTokenOwner(id, from);
            }
            _tokenOwners[id][from].amount = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev Internal function to burn a batch of tokens.
     * @param from The address to burn tokens from.
     * @param ids The IDs of the tokens to burn.
     * @param amounts The amounts of tokens to burn.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _tokenOwners[id][from].amount;
            require(
                fromBalance >= amount,
                "ERC1155: burn amount exceeds balance"
            );
            unchecked {
                if (amount == fromBalance) {
                    _tokenOwners[id][from].burned = true;
                    _removeTokenOwner(id, from);
                }
                _tokenOwners[id][from].amount = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {}

    // Function to add an owner for a specific token ID
    function _addTokenOwner(uint256 id, address owner) internal {
        if (!_tokenData[id].isOwner[owner]) {
            _tokenData[id].owners.push(owner);
            _tokenData[id].isOwner[owner] = true;
        }
    }

    // Function to remove an owner for a specific token ID
    function _removeTokenOwner(uint256 id, address owner) internal {
        require(_tokenData[id].isOwner[owner], "Owner not found");

        // Find the index of the owner in the array
        uint256 indexToRemove = 0;
        for (uint256 i = 0; i < _tokenData[id].owners.length; i++) {
            if (_tokenData[id].owners[i] == owner) {
                indexToRemove = i;
                break;
            }
        }

        // Swap the element to be removed with the last element and then remove the last element
        _tokenData[id].owners[indexToRemove] = _tokenData[id].owners[
            _tokenData[id].owners.length - 1
        ];
        _tokenData[id].owners.pop();
        _tokenData[id].isOwner[owner] = false;
    }

    // Function to get all owners of a specific token ID as a tuple
    function getTokenOwners(uint256 id) public view returns (address[] memory) {
        return _tokenData[id].owners;
    }

    // Function to check if an address owns a specific token ID
    function _checkOwnership(uint256 id, address owner)
        internal
        view
        returns (bool)
    {
        return _tokenData[id].isOwner[owner];
    }

    // Function to convert a uint256 to a one-element array
    function _asSingletonArray(uint256 element)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
}
