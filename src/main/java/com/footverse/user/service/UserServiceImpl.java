package com.footverse.user.service;

import java.util.Optional;

import org.springframework.stereotype.Service;

import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.mapper.UserMapper;
import com.footverse.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

/**
 * Default {@link UserService} implementation backed by {@link UserRepository} and
 * {@link UserMapper}.
 */
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

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
