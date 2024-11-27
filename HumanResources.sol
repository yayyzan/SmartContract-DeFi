// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;
import "./IHumanResources.sol";


abstract contract HumanResources is IHumanResources {

    enum preferredPay {USDC, ETH}

    struct Employee{
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 accumulated;
        preferredPay preference;
    }

    address public immutable hrManagerAddress; 
    mapping(address => Employee) public employeeMap;
    address[] public employeeAddresses;
    uint256 employeeCount;

    constructor(){
        hrManagerAddress = msg.sender; 
    }

    modifier onlyHrManager(){
        require(msg.sender == hrManagerAddress, NotAuthorized());
        _;
    }

    function salaryAvailable (address employee) external view returns (uint256){
        Employee memory employeeInfo = employeeMap[employee];
        return employeeInfo.weeklyUsdSalary;
    }

    function hrManager() external view returns (address){
        return hrManagerAddress;
    }

    function getActiveEmployeeCount() external view returns(uint256){
        return employeeCount;
    }

    function getEmployeeInfo(address employee) external view returns(uint256, uint256, uint256){
        Employee memory employeeInfo = employeeMap[employee];
        return (employeeInfo.weeklyUsdSalary, employeeInfo.employedSince, employeeInfo.terminatedAt);
    } 

    function registerEmployee (address employee, uint256 weeklyUsdSalary) onlyHrManager external {
        uint256 checkEmployee = employeeMap[employee].employedSince;
        uint256 checkEmployee2 = employeeMap[employee].terminatedAt;
        if (checkEmployee == 0){
            Employee memory newEmployee = Employee(weeklyUsdSalary * 10**18, block.timestamp, 0, 0, preferredPay.USDC);
            employeeMap[employee] = newEmployee;
            employeeAddresses.push(employee);
            employeeCount += 1;
            emit EmployeeRegistered(employee, weeklyUsdSalary);
        }
        else if (checkEmployee2 == 0){
            revert EmployeeAlreadyRegistered();
        }
        else {
            employeeMap[employee].weeklyUsdSalary = weeklyUsdSalary * 10**18;
            employeeMap[employee].employedSince = block.timestamp;
            employeeMap[employee].terminatedAt = 0;
        }
    }

    function terminateEmployee (address employee) onlyHrManager external {
        if(employeeMap[employee].employedSince  == 0){
            revert EmployeeNotRegistered();
        }
        employeeMap[employee].terminatedAt = block.timestamp;
        emit EmployeeTerminated(employee);
    }

    function 
    

    
}
