// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract TimeLock {

    address public owner;
    uint256 constant MIN_DELAY = 10;
    uint256 constant MAX_DELAY = 1000;
    uint256 constant GRACE_PERIOD = 100000;
    mapping(bytes32 => bool) public queued;

    event TransactionQueued(
        bytes32 indexed txId, 
        address indexed target, 
        uint value, 
        string indexed func, 
        bytes data, 
        uint timestamp
    );

    event Execute(
        bytes indexed txId, 
        address indexed _target, 
        uint _value,
        string indexed _func, 
        bytes _data,
        uint _timestamp
    );

    event Cancel(
        bytes indexed txId, 
        address indexed _target, 
        uint _value,
        string indexed _func, 
        bytes _data,
        uint _timestamp
    );
    

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function getTxId (
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) public pure returns (bytes32 txId) {
        return keccak256(
            abi.encode(
                _target, _value, _func, _data, _timestamp
            )
        );
    }

    function queue(
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) external {
        require(msg.sender == owner, 'Only owner can call this function');

        // Get transaction id
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        // Check if transaction is already queued
        require(!queued[txId], 'Transaction already in queue');

        // Check if timestamp is within min and max delays
        require(
            _timestamp < block.timestamp + MIN_DELAY ||
            _timestamp > block.timestamp + MAX_DELAY, 
            'Timestamp not within max and min delays'
        );

        // Queue transaction
        queued[txId] = true;

        emit TransactionQueued(txId, _target, _value, _func, _data, _timestamp);

    }

    function execute(
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) external payable returns (bytes memory) {
        require(msg.sender == owner, 'Only owner can call this function');
        
        // Get transaction id
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        // Check if transaction is in queue
        require(queued[txId], 'Transaction is not in queue');

        // Check if timestamp delay has passed
        require(block.timestamp > _timestamp, 'Timestamp has not passed yet');
        require(block.timestamp < _timestamp + GRACE_PERIOD, 'Timestamp has passed grace period');

        // Get function data
        bytes memory data = getFunctionData(_data, _func);

        // Execute Transaction
        (bool ok, bytes memory res) = _target.call{value: value}(data);

        // Check transaction
        require(ok, 'Transaction not successful');
        emit Execute(txId, _target, _value, _func, _data, _timestamp);

        // Change queue state
        queued[txId] = false;

        return res;
    }

    function cancel(
        address _target,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) external {
        require(msg.sender == owner, 'Only the owner can call this function');

        // Get transaction id
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        // Check if transaction is in queue
        require(queued[txId] == true, 'Transaction is not in queue');

        // Set queue to false
        queued[txId] = false;

        emit Cancel(txId,_target, _value, _func, _data, _timestamp);
    }

    function getFunctionData(
        bytes calldata _data, 
        string calldata _func
    ) 
        public pure returns (bytes) 
    {
        bytes memory data;
        if (bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))), _data
            );
        } else {
            data = _data;
        }
        return data;
    }
}

contract TestTimeLock {
    address public timeLock;

    constructor(address _timeLock) {
        timeLock = _timeLock;
    }

    function test() external {
        require(msg.sender == timeLock);
        // execute code here: upgrades, transfers, switching oracles
    }
}