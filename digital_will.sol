// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Digital Will
 * @dev A smart contract for creating and managing digital wills on the blockchain
 */
contract Project {
    
    struct Beneficiary {
        address beneficiaryAddress;
        uint256 sharePercentage;
        bool claimed;
    }
    
    struct Will {
        address owner;
        uint256 totalAmount;
        uint256 lastCheckIn;
        uint256 inactivityPeriod;
        bool isActive;
        bool isExecuted;
        Beneficiary[] beneficiaries;
    }
    
    mapping(address => Will) public wills;
    mapping(address => bool) public hasWill;
    
    event WillCreated(address indexed owner, uint256 inactivityPeriod);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 sharePercentage);
    event CheckInPerformed(address indexed owner, uint256 timestamp);
    event WillExecuted(address indexed owner, uint256 totalAmount);
    event FundsDeposited(address indexed owner, uint256 amount);
    
    modifier onlyWillOwner() {
        require(hasWill[msg.sender], "No will exists for this address");
        require(wills[msg.sender].owner == msg.sender, "Not the will owner");
        _;
    }
    
    modifier willNotExecuted() {
        require(!wills[msg.sender].isExecuted, "Will already executed");
        _;
    }
    
    /**
     * @dev Creates a new digital will with specified inactivity period
     * @param _inactivityPeriod Time in seconds after which will can be executed if no check-in
     */
    function createWill(uint256 _inactivityPeriod) external {
        require(!hasWill[msg.sender], "Will already exists");
        require(_inactivityPeriod > 0, "Inactivity period must be greater than 0");
        
        wills[msg.sender].owner = msg.sender;
        wills[msg.sender].totalAmount = 0;
        wills[msg.sender].lastCheckIn = block.timestamp;
        wills[msg.sender].inactivityPeriod = _inactivityPeriod;
        wills[msg.sender].isActive = true;
        wills[msg.sender].isExecuted = false;
        
        hasWill[msg.sender] = true;
        
        emit WillCreated(msg.sender, _inactivityPeriod);
    }
    
    /**
     * @dev Adds a beneficiary to the will with their share percentage
     * @param _beneficiary Address of the beneficiary
     * @param _sharePercentage Percentage of funds (0-100)
     */
    function addBeneficiary(address _beneficiary, uint256 _sharePercentage) 
        external 
        onlyWillOwner 
        willNotExecuted 
    {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_sharePercentage > 0 && _sharePercentage <= 100, "Invalid share percentage");
        
        Will storage will = wills[msg.sender];
        
        uint256 totalShares = 0;
        for (uint256 i = 0; i < will.beneficiaries.length; i++) {
            totalShares += will.beneficiaries[i].sharePercentage;
        }
        
        require(totalShares + _sharePercentage <= 100, "Total shares exceed 100%");
        
        will.beneficiaries.push(Beneficiary({
            beneficiaryAddress: _beneficiary,
            sharePercentage: _sharePercentage,
            claimed: false
        }));
        
        emit BeneficiaryAdded(msg.sender, _beneficiary, _sharePercentage);
    }
    
    /**
     * @dev Owner performs check-in to reset the inactivity timer
     */
    function checkIn() external onlyWillOwner willNotExecuted {
        Will storage will = wills[msg.sender];
        will.lastCheckIn = block.timestamp;
        
        emit CheckInPerformed(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Deposit funds into the will
     */
    function depositFunds() external payable onlyWillOwner willNotExecuted {
        require(msg.value > 0, "Must send some ether");
        
        Will storage will = wills[msg.sender];
        will.totalAmount += msg.value;
        
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Execute the will and distribute funds to beneficiaries
     * @param _ownerAddress Address of the will owner
     */
    function executeWill(address _ownerAddress) external {
        require(hasWill[_ownerAddress], "No will exists for this address");
        
        Will storage will = wills[_ownerAddress];
        require(!will.isExecuted, "Will already executed");
        require(will.isActive, "Will is not active");
        require(
            block.timestamp >= will.lastCheckIn + will.inactivityPeriod,
            "Inactivity period not reached"
        );
        require(will.beneficiaries.length > 0, "No beneficiaries added");
        
        will.isExecuted = true;
        will.isActive = false;
        
        uint256 totalAmount = will.totalAmount;
        
        for (uint256 i = 0; i < will.beneficiaries.length; i++) {
            Beneficiary storage beneficiary = will.beneficiaries[i];
            if (!beneficiary.claimed) {
                uint256 amount = (totalAmount * beneficiary.sharePercentage) / 100;
                beneficiary.claimed = true;
                
                (bool success, ) = beneficiary.beneficiaryAddress.call{value: amount}("");
                require(success, "Transfer failed");
            }
        }
        
        emit WillExecuted(_ownerAddress, totalAmount);
    }
    
    /**
     * @dev Get beneficiaries for a will
     * @param _owner Address of the will owner
     */
    function getBeneficiaries(address _owner) external view returns (Beneficiary[] memory) {
        require(hasWill[_owner], "No will exists for this address");
        return wills[_owner].beneficiaries;
    }
    
    /**
     * @dev Get will details
     * @param _owner Address of the will owner
     */
    function getWillDetails(address _owner) external view returns (
        uint256 totalAmount,
        uint256 lastCheckIn,
        uint256 inactivityPeriod,
        bool isActive,
        bool isExecuted,
        uint256 beneficiaryCount
    ) {
        require(hasWill[_owner], "No will exists for this address");
        Will storage will = wills[_owner];
        
        return (
            will.totalAmount,
            will.lastCheckIn,
            will.inactivityPeriod,
            will.isActive,
            will.isExecuted,
            will.beneficiaries.length
        );
    }
    
    /**
     * @dev Check if will can be executed
     * @param _owner Address of the will owner
     */
    function canExecuteWill(address _owner) external view returns (bool) {
        if (!hasWill[_owner]) return false;
        
        Will storage will = wills[_owner];
        
        return (
            !will.isExecuted &&
            will.isActive &&
            block.timestamp >= will.lastCheckIn + will.inactivityPeriod &&
            will.beneficiaries.length > 0
        );
    }
}
