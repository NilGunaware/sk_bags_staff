import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiResponseHandler {
  ApiResponseHandler._();

  static final Map<String, DateTime> _messageTimestamps =
      <String, DateTime>{};
  static const int _messageCooldownSeconds = 5;
  static bool silentErrors = true;

  static bool handleResponse(
    dynamic response, {
    bool showSuccessMessage = true,
    bool showErrorMessage = false,
  }) {
    try {
      final Map<String, dynamic> responseData = _asMap(response);
      final bool status = responseData['status'] == true;
      final String message = responseData['message']?.toString().trim() ?? '';

      if (!status) {
        if (!silentErrors && showErrorMessage && message.isNotEmpty) {
          _showMessage(message, isSuccess: false);
        }
        return false;
      }

      if (showSuccessMessage && message.isNotEmpty) {
        _showMessage(message, isSuccess: true);
      }

      return true;
    } catch (_) {
     // _showMessage(AppStrings.defaultError, isSuccess: false);
      return false;
    }
  }

  static Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is String) {
      return jsonDecode(response) as Map<String, dynamic>;
    }
    throw ApiException('Invalid response received from server.');
  }

  static void showSuccessSnackbar(String message) =>
      _showMessage(message, isSuccess: true);
  static void showErrorSnackbar(String message) =>
      silentErrors ? null : _showMessage(message, isSuccess: false);

  static void _showMessage(String message, {required bool isSuccess}) {
    if (!isSuccess && silentErrors) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    if (!_shouldShowMessage(trimmed)) return;
    _recordMessage(trimmed);

    Get.snackbar(
      '',
      trimmed,
      snackPosition: SnackPosition.TOP,
      backgroundColor: isSuccess ? AppColors.primary : Colors.redAccent,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: Colors.white,
      ),
    );
  }

  static bool _shouldShowMessage(String message) {
    final key = message.trim().isEmpty ? '_default_' : message.trim();
    final now = DateTime.now();
    final last = _messageTimestamps[key];
    if (last == null) {
      return true;
    }
    final diff = now.difference(last).inSeconds;
    return diff >= _messageCooldownSeconds;
  }

  static void _recordMessage(String message) {
    final key = message.trim().isEmpty ? '_default_' : message.trim();
    _messageTimestamps[key] = DateTime.now();
    _cleanupOldMessages();
  }

  static void _cleanupOldMessages() {
    final keysToRemove = <String>[];
    final now = DateTime.now();
    _messageTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp).inSeconds >
          _messageCooldownSeconds * 2) {
        keysToRemove.add(key);
      }
    });
    for (final key in keysToRemove) {
      _messageTimestamps.remove(key);
    }
  }

  static void clearMessageHistory() {
    _messageTimestamps.clear();
  }
}

