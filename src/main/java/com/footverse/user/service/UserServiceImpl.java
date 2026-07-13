package com.footverse.user.service;

import java.util.Locale;
import java.util.Optional;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.security.CurrentUserProvider;
import com.footverse.user.dto.ChangeEmailRequest;
import com.footverse.user.dto.ChangePasswordRequest;
import com.footverse.user.dto.UpdateProfileRequest;
import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.mapper.UserMapper;
import com.footverse.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

/**
 * Default {@link UserService} implementation backed by {@link UserRepository} and
 * {@link UserMapper}. The current-user lookup reads the authenticated user through
 * {@link CurrentUserProvider}, never the security context directly.
 */
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private static final String USER_PHONE_DUPLICATED_CODE = "USER_PHONE_DUPLICATED";
    private static final String USER_PHONE_DUPLICATED_MESSAGE = "Phone already exists";
    private static final String USER_EMAIL_DUPLICATED_CODE = "USER_EMAIL_DUPLICATED";
    private static final String USER_EMAIL_DUPLICATED_MESSAGE = "Email already exists";
    private static final String USER_CURRENT_PASSWORD_INVALID_CODE = "USER_CURRENT_PASSWORD_INVALID";
    private static final String USER_CURRENT_PASSWORD_INVALID_MESSAGE = "Current password is incorrect";

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final CurrentUserProvider currentUserProvider;
    private final PasswordEncoder passwordEncoder;

    @Override
    public UserResponse getCurrentUser() {
        return userMapper.toResponse(currentUserProvider.getCurrentUser());
    }

    @Override
    @Transactional
    public UserResponse updateProfile(UpdateProfileRequest request) {
        User user = currentUserProvider.getCurrentUser();
        // Only a phone that changed and is held by another account is a conflict; keeping one's own
        // phone is not (the coupon-update precedent), so the existing exists-check is guarded by the
        // change and never trips on the caller's current phone.
        if (!user.getPhone().equals(request.phone()) && userRepository.existsByPhone(request.phone())) {
            throw new DuplicateResourceException(USER_PHONE_DUPLICATED_CODE, USER_PHONE_DUPLICATED_MESSAGE);
        }
        user.setFullName(request.fullName());
        user.setPhone(request.phone());
        user.setAvatarUrl(request.avatarUrl());
        return userMapper.toResponse(persistProfile(user));
    }

    /**
     * Persists the profile change, forcing the flush now so the {@code uk_user_phone} unique
     * constraint is checked inside this call: a race that beats the service-level
     * {@code existsByPhone} guard surfaces as a {@link DataIntegrityViolationException}, which is
     * translated to the same enveloped {@code 409 USER_PHONE_DUPLICATED} rather than leaking a
     * database error as a {@code 500} (the {@code ReviewServiceImpl.persistNew} precedent). Phone is
     * the only unique column this update can touch — email is never changed here — so the constraint
     * violation is unambiguously the duplicate phone.
     *
     * @param user the caller's profile to persist
     * @return the persisted user
     * @throws DuplicateResourceException {@code 409 USER_PHONE_DUPLICATED} when the unique constraint fires
     */
    private User persistProfile(User user) {
        try {
            return userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException duplicate) {
            throw new DuplicateResourceException(USER_PHONE_DUPLICATED_CODE, USER_PHONE_DUPLICATED_MESSAGE);
        }
    }

    @Override
    @Transactional
    public void changePassword(ChangePasswordRequest request) {
        User user = currentUserProvider.getCurrentUser();
        verifyCurrentPassword(request.currentPassword(), user);
        // Encode the raw password with BCrypt before it ever touches the entity; the raw value is
        // never stored, logged, or echoed (business-rules → Security). No frozen rule forbids a new
        // password equal to the current one, so none is enforced here.
        user.setPassword(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
    }

    @Override
    @Transactional
    public UserResponse changeEmail(ChangeEmailRequest request) {
        User user = currentUserProvider.getCurrentUser();
        verifyCurrentPassword(request.currentPassword(), user);
        String normalizedEmail = request.newEmail().toLowerCase(Locale.ROOT);
        // Only an email that changed and is held by another account is a conflict; resubmitting one's
        // own current email is an idempotent no-op (the profile-phone / coupon-update precedent), so
        // the exists-check is guarded by the change and never trips on the caller's own row.
        if (!user.getEmail().equals(normalizedEmail) && userRepository.existsByEmail(normalizedEmail)) {
            throw new DuplicateResourceException(USER_EMAIL_DUPLICATED_CODE, USER_EMAIL_DUPLICATED_MESSAGE);
        }
        user.setEmail(normalizedEmail);
        return userMapper.toResponse(persistEmail(user));
    }

    /**
     * Verifies the supplied raw password against the user's stored BCrypt hash with the shared
     * {@link PasswordEncoder}, never a hand-rolled comparison (business-rules → Security). A mismatch
     * is the enveloped {@code 400 USER_CURRENT_PASSWORD_INVALID} (an input-based business rejection
     * inside an authenticated call — deliberately not {@code 401}, which is reserved for the token
     * layer, error-spec §3). The raw password is never logged or echoed.
     *
     * @param rawCurrentPassword the caller-supplied current password
     * @param user               the authenticated caller
     * @throws BusinessException {@code 400 USER_CURRENT_PASSWORD_INVALID} when the password does not match
     */
    private void verifyCurrentPassword(String rawCurrentPassword, User user) {
        if (!passwordEncoder.matches(rawCurrentPassword, user.getPassword())) {
            throw new BusinessException(HttpStatus.BAD_REQUEST,
                    USER_CURRENT_PASSWORD_INVALID_CODE, USER_CURRENT_PASSWORD_INVALID_MESSAGE);
        }
    }

    /**
     * Persists the email change, forcing the flush now so the {@code uk_user_email} unique constraint
     * is checked inside this call: a race that beats the service-level {@code existsByEmail} guard
     * surfaces as a {@link DataIntegrityViolationException}, translated to the same enveloped
     * {@code 409 USER_EMAIL_DUPLICATED} rather than leaking a database error as a {@code 500} (the
     * {@link #persistProfile} precedent). Email is the only unique column this change touches, so the
     * violation is unambiguously the duplicate email.
     *
     * @param user the caller with the new email set
     * @return the persisted user
     * @throws DuplicateResourceException {@code 409 USER_EMAIL_DUPLICATED} when the unique constraint fires
     */
    private User persistEmail(User user) {
        try {
            return userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException duplicate) {
            throw new DuplicateResourceException(USER_EMAIL_DUPLICATED_CODE, USER_EMAIL_DUPLICATED_MESSAGE);
        }
    }

    @Override
    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }

    @Override
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    @Override
    public boolean existsByPhone(String phone) {
        return userRepository.existsByPhone(phone);
    }

    @Override
    public User createUser(String email, String encodedPassword, String fullName, String phone) {
        User user = new User();
        user.setEmail(email);
        user.setPassword(encodedPassword);
        user.setFullName(fullName);
        user.setPhone(phone);
        user.setRole(Role.CUSTOMER);
        user.setEnabled(true);
        return userRepository.save(user);
    }

    @Override
    public UserResponse toResponse(User user) {
        return userMapper.toResponse(user);
    }
}
