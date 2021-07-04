pragma solidity 0.8.3;

import "./EvohERC721.sol";

contract EvohClaimable is EvohERC721 {

    uint256 public maxTotalSupply;
    bytes32 public hashRoot;
    address public owner;

    struct ClaimData {
        bytes32 root;
        uint256 count;
        uint256 limit;
        mapping(address => bool) claimed;
    }

    ClaimData[] public claimData;

    constructor(
        string memory _name,
        string memory _symbol,
        bytes32 _hashRoot,
        uint256 _maxTotalSupply
    )
        EvohERC721(_name, _symbol)
    {
        owner = msg.sender;
        hashRoot = _hashRoot;
        maxTotalSupply = _maxTotalSupply;
    }

    function addClaimRoots(bytes32[] calldata _merkleRoots, uint256[] calldata _claimLimits) external {
        require(msg.sender == owner);
        for (uint256 i = 0; i < _merkleRoots.length; i++) {
            ClaimData storage data = claimData.push();
            data.root = _merkleRoots[i];
            data.limit = _claimLimits[i];
        }
    }

    function isClaimed(uint256 _claimIndex, address _account) public view returns (bool) {
        return claimData[_claimIndex].claimed[_account];
    }

    /**
        @notice Claim an NFT using an eligible account
        @dev Claiming requires two proofs. The "claim proof" validates that the calling
             address is eligible to claim the airdrop. The "hash proof" valides that the
             given IPFS hash for the airdropped NFT is valid, and comes next within the
             sequence of claimable hashes.
        @param _claimIndex Index of the claim hash to validate `_claimProof` against
        @param _hashIndex Index of the hash proof being used. Hash proofs must be
                          provided sequentially in order to be valid.
        @param _hash IPFS hash of the NFT being claimed
        @param _claimProof Proof to validate against the claim root
        @param _hashProof Proof to validate against the hash root
     */
    function claim(
        uint256 _claimIndex,
        uint256 _hashIndex,
        string calldata _hash,
        bytes32[] calldata _claimProof,
        bytes32[] calldata _hashProof
    )
        external
    {
        uint256 claimed = totalSupply;
        require(maxTotalSupply > claimed, "All NFTs claimed");

        // Verify the NFT hash
        bytes32 node = keccak256(abi.encodePacked(_hashIndex, _hash));
        require(_hashIndex == claimed, "Incorrect hash index");
        require(verify(_hashProof, hashRoot, node), "Invalid hash proof");

        // Verify the claim
        node = keccak256(abi.encodePacked(msg.sender));
        ClaimData storage data = claimData[_claimIndex];

        require(_claimIndex < claimData.length, "Invalid merkleIndex");
        require(data.count < data.limit, "All NFTs claimed in this airdrop");
        require(!data.claimed[msg.sender], "User has claimed in this airdrop");
        require(verify(_claimProof, data.root, node), "Invalid claim proof");

        // Mark as claimed, write the hash and send the token.
        data.count++;
        data.claimed[msg.sender] = true;
        tokenURIs[claimed] = _hash;

        addOwnership(msg.sender, claimed);
        emit Transfer(address(0), msg.sender, claimed);
        totalSupply = claimed + 1;
    }

    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    )
        internal
        pure
        returns (bool)
    {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }


}
