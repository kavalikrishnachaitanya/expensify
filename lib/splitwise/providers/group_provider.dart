import 'package:flutter/material.dart';
import 'package:expenses/splitwise/models/group_model.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/services/firestore_service.dart';
import 'package:expenses/utils/id_generator.dart';
import 'dart:async';

/// Provider for group management
class GroupProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _groupsSubscription;

  List<GroupModel> _groups = [];
  GroupModel? _selectedGroup;
  bool _isLoading = false;
  String? _error;

  List<GroupModel> get groups => _groups;
  GroupModel? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load groups for user
  void loadUserGroups(String userId) {
    _groupsSubscription?.cancel();
    
    _groupsSubscription = _firestoreService.getUserGroups(userId).listen(
      (groups) {
        _groups = groups;
        _error = null; // Clear error on success
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Create a new group
  Future<String?> createGroup({
    required String name,
    String? description,
    required String userId,
    required String userName,
    List<String>? initialMemberNames,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final memberIds = <String>[userId];
      final memberNamesMap = <String, String>{userId: userName};

      if (initialMemberNames != null) {
        for (int i = 0; i < initialMemberNames.length; i++) {
          final mName = initialMemberNames[i].trim();
          if (mName.isNotEmpty) {
            final mId = IdGenerator.generate('mbr');
            memberIds.add(mId);
            memberNamesMap[mId] = mName;
          }
        }
      }

      final group = GroupModel(
        id: '',
        name: name,
        description: description,
        memberIds: memberIds,
        memberNames: memberNamesMap,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      final groupId = await _firestoreService.createGroup(group);
      _setLoading(false);
      return groupId;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return null;
    }
  }

  /// Select a group
  void selectGroup(GroupModel group) {
    _selectedGroup = group;
    notifyListeners();
  }

  /// Add member to group by email. Returns null on success, or error message string on failure.
  Future<String?> addMemberByEmail(String groupId, String email) async {
    _setLoading(true);

    try {
      final user = await _firestoreService.getUserByEmail(email);
      if (user == null) {
        _setLoading(false);
        return 'User not found with that email';
      }

      // Check if already a member
      if (_selectedGroup?.memberIds.contains(user.uid) ?? false) {
        _setLoading(false);
        return 'User is already a member of this group';
      }

      await _firestoreService.addMemberToGroup(
        groupId,
        user.uid,
        user.displayName,
      );

      // Refresh selected group
      final updatedGroup = await _firestoreService.getGroup(groupId);
      if (updatedGroup != null) {
        _selectedGroup = updatedGroup;
      }

      _setLoading(false);
      return null; // Success!
    } catch (e) {
      _setLoading(false);
      return e.toString();
    }
  }

  /// Remove member from group
  Future<bool> removeMember(String groupId, String userId) async {
    _setLoading(true);
    _error = null;

    try {
      await _firestoreService.removeMemberFromGroup(groupId, userId);

      // Refresh selected group
      final updatedGroup = await _firestoreService.getGroup(groupId);
      if (updatedGroup != null) {
        _selectedGroup = updatedGroup;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Delete group
  Future<bool> deleteGroup(String groupId) async {
    _setLoading(true);
    _error = null;

    try {
      await _firestoreService.deleteGroup(groupId);
      _selectedGroup = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data (for logout)
  void clearData() {
    _groupsSubscription?.cancel();
    _groups = [];
    _selectedGroup = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Get user details by ID
  Future<UserModel?> getUserDetails(String userId) async {
    return await _firestoreService.getUser(userId);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _groupsSubscription?.cancel();
    super.dispose();
  }
}
