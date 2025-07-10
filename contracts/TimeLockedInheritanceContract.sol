// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Time-Locked Inheritance Contract
 * @dev A smart contract that manages inheritance with time-locked releases
 * @author Your Name
 */
contract Project {
    // State variables
    address public owner;
    bool public isActive;
    uint256 public totalInheritance;
    uint256 public lockPeriod;
    uint256 public deploymentTime;
    
    // Beneficiary structure
    struct Beneficiary {
        address beneficiaryAddress;
        uint256 sharePercentage;
        uint256 claimedAmount;
        bool isActive;
        uint256 lastClaimTime;
    }
    
    // Mappings and arrays
    mapping(address => Beneficiary) public beneficiaries;
    address[] public beneficiaryList;
    
    // Events
    event BeneficiaryAdded(address indexed beneficiary, uint256 sharePercentage);
    event BeneficiaryUpdated(address indexed beneficiary, uint256 newSharePercentage);
    event InheritanceClaimed(address indexed beneficiary, uint256 amount);
    event FundsDeposited(uint256 amount);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActiveBeneficiary() {
        require(beneficiaries[msg.sender].isActive, "Not an active beneficiary");
        _;
    }
    
    modifier contractActive() {
        require(isActive, "Contract is not active");
        _;
    }
    
    /**
     * @dev Constructor to initialize the inheritance contract
     * @param _lockPeriod Time in seconds before inheritance can be claimed
     */
    constructor(uint256 _lockPeriod) {
        owner = msg.sender;
        lockPeriod = _lockPeriod;
        deploymentTime = block.timestamp;
        isActive = true;
        totalInheritance = 0;
    }
    
    /**
     * @dev Core Function 1: Add or update beneficiaries with their inheritance share
     * @param _beneficiary Address of the beneficiary
     * @param _sharePercentage Percentage of inheritance (0-100)
     */
    function manageBeneficiary(address _beneficiary, uint256 _sharePercentage) 
        external 
        onlyOwner 
        contractActive 
    {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_sharePercentage > 0 && _sharePercentage <= 100, "Share must be between 1-100%");
        
        // Check if total shares don't exceed 100%
        uint256 totalShares = _sharePercentage;
        for (uint256 i = 0; i < beneficiaryList.length; i++) {
            address addr = beneficiaryList[i];
            if (addr != _beneficiary && beneficiaries[addr].isActive) {
                totalShares += beneficiaries[addr].sharePercentage;
            }
        }
        require(totalShares <= 100, "Total shares exceed 100%");
        
        // Add new beneficiary or update existing
        if (beneficiaries[_beneficiary].beneficiaryAddress == address(0)) {
            beneficiaries[_beneficiary] = Beneficiary({
                beneficiaryAddress: _beneficiary,
                sharePercentage: _sharePercentage,
                claimedAmount: 0,
                isActive: true,
                lastClaimTime: 0
            });
            beneficiaryList.push(_beneficiary);
            emit BeneficiaryAdded(_beneficiary, _sharePercentage);
        } else {
            beneficiaries[_beneficiary].sharePercentage = _sharePercentage;
            beneficiaries[_beneficiary].isActive = true;
            emit BeneficiaryUpdated(_beneficiary, _sharePercentage);
        }
    }
    
    /**
     * @dev Core Function 2: Claim inheritance (only after lock period)
     * Allows beneficiaries to claim their share of inheritance
     */
    function claimInheritance() 
        external 
        onlyActiveBeneficiary 
        contractActive 
    {
        require(block.timestamp >= deploymentTime + lockPeriod, "Lock period not yet expired");
        require(address(this).balance > 0, "No funds available");
        
        Beneficiary storage beneficiary = beneficiaries[msg.sender];
        
        // Calculate claimable amount
        uint256 totalShare = (address(this).balance * beneficiary.sharePercentage) / 100;
        uint256 claimableAmount = totalShare - beneficiary.claimedAmount;
        
        require(claimableAmount > 0, "No claimable amount available");
        
        // Update claimed amount
        beneficiary.claimedAmount += claimableAmount;
        beneficiary.lastClaimTime = block.timestamp;
        
        // Transfer funds
        payable(msg.sender).transfer(claimableAmount);
        
        emit InheritanceClaimed(msg.sender, claimableAmount);
    }
    
    /**
     * @dev Core Function 3: Emergency withdrawal (owner only, with conditions)
     * Allows owner to withdraw funds in emergency situations
     */
    function emergencyWithdrawal() 
        external 
        onlyOwner 
    {
        require(address(this).balance > 0, "No funds to withdraw");
        
        // Emergency withdrawal only allowed in first 30 days after deployment
        // or if no beneficiaries are set
        bool canWithdraw = (block.timestamp <= deploymentTime + 30 days) || 
                          (beneficiaryList.length == 0);
        
        require(canWithdraw, "Emergency withdrawal not allowed at this time");
        
        uint256 amount = address(this).balance;
        payable(owner).transfer(amount);
        
        emit EmergencyWithdrawal(owner, amount);
    }
    
    /**
     * @dev Deposit funds to the contract
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Must send some ETH");
        totalInheritance += msg.value;
        emit FundsDeposited(msg.value);
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Get beneficiary details
     */
    function getBeneficiaryDetails(address _beneficiary) 
        external 
        view 
        returns (
            uint256 sharePercentage,
            uint256 claimedAmount,
            bool beneficiaryActive,
            uint256 lastClaimTime
        ) 
    {
        Beneficiary memory beneficiary = beneficiaries[_beneficiary];
        return (
            beneficiary.sharePercentage,
            beneficiary.claimedAmount,
            beneficiary.isActive,
            beneficiary.lastClaimTime
        );
    }
    
    /**
     * @dev Get time remaining until inheritance unlock
     */
    function getTimeUntilUnlock() external view returns (uint256) {
        if (block.timestamp >= deploymentTime + lockPeriod) {
            return 0;
        }
        return (deploymentTime + lockPeriod) - block.timestamp;
    }
    
    /**
     * @dev Get all beneficiaries
     */
    function getAllBeneficiaries() external view returns (address[] memory) {
        return beneficiaryList;
    }
    
    /**
     * @dev Deactivate contract (owner only)
     */
    function deactivateContract() external onlyOwner {
        isActive = false;
    }
    
    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        totalInheritance += msg.value;
        emit FundsDeposited(msg.value);
    }
}
