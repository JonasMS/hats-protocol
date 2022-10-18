// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import "forge-std/Test.sol"; //remove after testing
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Hats Id Utilities
/// @dev Functions for working with Hat Ids from Hats Protocol. Factored out of Hats.sol
/// for easier use by other contracts.
/// @author Hats Protocol
contract HatsIdUtilities {
    /**
     * Hat Ids serve as addresses. A given Hat's Id represents its location in its
     * hat tree: its level, its admin, its admin's admin (etc, all the way up to the
     * tophat).
     *
     * The top level consists of 4 bytes and references all tophats.
     *
     * Each level below consists of 1 byte, and contains up to 255 child hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses and 28 additional bytes
     * of space, giving room for 28 levels of delegation, with the admin at each level
     * having space for 255 different child hats.
     *
     * A hat tree consists of a single tophat and has a max depth of 28 levels.
     */

    uint256 internal constant TOPHAT_ADDRESS_SPACE = 32; // 32 bits (4 bytes) of space for tophats, aka the "domain"
    uint256 internal constant LOWER_LEVEL_ADDRESS_SPACE = 8; // 8 bits (1 byte) of space for each of the levels below the tophat
    uint256 internal constant MAX_LEVELS = 28; // 28 levels below the tophat

    error MaxLevelsReached();

    /// @notice Constructs a valid hat id for a new hat underneath a given admin
    /// @dev Check hats[_admin].lastHatId for the previous hat created underneath _admin.
    /// Assumes _admin is a valid hat id.
    /// @param _admin the id of the admin for the new hat. Must be a valid hat id.
    /// @param _newHat the uint8 id of the new hat
    /// @return uint256 The constructed hat id
    function buildHatId(uint256 _admin, uint8 _newHat)
        public
        view
        returns (uint256)
    {
        uint256 mask;

        for (uint256 i = 0; i < MAX_LEVELS; ) {
            // cannot overflow given known constants
            unchecked {
                mask = uint256(
                    type(uint256).max >>
                        (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
                );
            }

            if (_admin & mask == 0) {
                // cannot overflow given known constants
                unchecked {
                    return
                        _admin |
                        (uint256(_newHat) <<
                            (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - 1 - i)));
                }
            }

            unchecked {
                ++i;
            }
        }

        revert MaxLevelsReached();
    }

    /// @notice Identifies the level a given hat in its hat tree
    /// @param _hatId the id of the hat in question
    /// @return level (0 to 28)
    function getHatLevel(uint256 _hatId) public pure returns (uint8) {
        uint256 mask;
        uint256 i;
        for (i = 0; i < MAX_LEVELS; ) {
            unchecked {
                mask = uint256(
                    type(uint256).max >>
                        // cannot overflow given known constants
                        (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
                );
            }

            if (_hatId & mask == 0) return uint8(i);

            unchecked {
                ++i;
            }
        }

        return uint8(MAX_LEVELS);
    }

    /// @notice Checks whether a hat is a topHat
    /// @dev For use when passing a Hat object is not appropriate
    /// @param _hatId The hat in question
    /// @return bool Whether the hat is a topHat
    function isTopHat(uint256 _hatId) public pure returns (bool) {
        return _hatId > 0 && uint224(_hatId) == 0;
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return uint256 The hat id of the resulting admin
    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        public
        pure
        returns (uint256)
    {
        uint256 mask;
        unchecked {
            mask =
                type(uint256).max <<
                // cannot overflow given known constants
                (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - _level));
        }

        return _hatId & mask;
    }

    /// @notice Gets the tophat domain of a given hat
    /// @dev A domain is the identifier for a given hat tree, stored in the first 4 bytes of a hat's id
    /// @param _hatId the id of the hat in question
    /// @return domain The domain
    function getTophatDomain(uint256 _hatId)
        public
        pure
        returns (uint256 domain)
    {
        unchecked {
            domain =
                getAdminAtLevel(_hatId, 0) >>
                // cannot overflow given known constants
                (LOWER_LEVEL_ADDRESS_SPACE * MAX_LEVELS);
        }
    }
}
