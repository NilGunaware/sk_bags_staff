import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.grey[100]!, Colors.white, Colors.grey[100]!]),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _buildHeroCard(textTheme),
                        const SizedBox(height: 24),
                        _buildLoginCard(colorScheme, textTheme, context),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(AppStrings.appName, style: textTheme.labelMedium?.copyWith(letterSpacing: 1, color: Colors.grey[600])),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(TextTheme textTheme) {
    return Card(
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Workshop Login",
                    style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Sign in to manage workshop repairs", style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(ColorScheme colorScheme, TextTheme textTheme, BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.loginButton,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),

              // Mobile Number Field
              TextFormField(
                controller: controller.mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: AppStrings.mobileLabel,
                  prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                  filled: true,
                  fillColor: Colors.grey[50],
                  counterText: "",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppStrings.mobileRequired;
                  if (value.trim().length != 10) return 'Mobile number must be 10 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mandatory Branch Dropdown
              Obx(
                () => DropdownButtonFormField<String>(
                  initialValue: controller.selectedBranchId.value,
                  items: controller.branches
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b['id'] as String,
                          child: Text(b['name'] as String, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                  onChanged: controller.isBranchLoading.value ? null : (val) => controller.selectedBranchId.value = val,
                  decoration: InputDecoration(
                    labelText: controller.isBranchLoading.value ? 'Loading Branches...' : 'Select Branch',
                    prefixIcon: Icon(Icons.location_on_outlined, color: colorScheme.primary),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixIcon: controller.isBranchLoading.value ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please select a branch';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              Obx(
                () => TextFormField(
                  controller: controller.passwordController,
                  obscureText: controller.isPasswordHidden.value,
                  decoration: InputDecoration(
                    labelText: AppStrings.passwordLabel,
                    prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
                    suffixIcon: IconButton(
                      onPressed: controller.togglePasswordVisibility,
                      icon: Icon(controller.isPasswordHidden.value ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colorScheme.primary),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Login Button
              Obx(
                () => FilledButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          controller.submit();
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: controller.isLoading.value ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text(AppStrings.loginButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
