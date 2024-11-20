// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;
import "./IHumanResources.sol";


abstract contract HumanResources is IHumanResources {

    struct Employee{
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
    }

    address public immutable hrManagerAddress; 
    mapping(address => Employee) public employeeMap;
    address[] public employeeAddresses;

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
        uint256 count = 0;
        for(uint256 i; i < employeeAddresses.length; i++){
            Employee memory currentEmployee = employeeMap[employeeAddresses[i]];
            if(currentEmployee.terminatedAt == 0){
                count++;
            }
        }
        return count;
    }

    function getEmployeeInfo(address employee) external view returns(uint256, uint256, uint256){
        Employee memory employeeInfo = employeeMap[employee];
        return (employeeInfo.weeklyUsdSalary, employeeInfo.employedSince, employeeInfo.terminatedAt);
    } 

    // set to 18 decimal places
    // read spec!
    // complete implementation, check if accumulated salary should continue or not
    function registerEmployee (address employee, uint256 weeklyUsdSalary) external {
        uint256 checkEmployee = employeeMap[employee].weeklyUsdSalary;
        if (checkEmployee == 0){
            Employee memory newEmployee = Employee(weeklyUsdSalary, block.timestamp, 0);
            employeeMap[employee] = newEmployee;
            employeeAddresses.push(employee);

            emit EmployeeRegistered(employee, weeklyUsdSalary);
        }
        else {
            revert EmployeeAlreadyRegistered();
        }
    }



    
}
