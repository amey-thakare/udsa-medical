import { Response, NextFunction } from 'express';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { config } from '../config/env';
import { AuthRequest } from '../middleware/auth';
import { AppError, UnauthorizedError, ValidationError, ConflictError } from '../utils/errors';

const prisma = new PrismaClient();

const registerSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  name: z.string().min(1, 'Name is required').max(100),
});

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

function generateToken(userId: string): string {
  return jwt.sign({ userId }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  } as jwt.SignOptions);
}

export async function register(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const data = registerSchema.parse(req.body);
    console.log(`[AUTH] Registration request received for email: ${data.email}, name: ${data.name}`);

    // Check if user exists
    console.log(`[AUTH] Querying database for existing user...`);
    const existing = await prisma.user.findUnique({ where: { email: data.email } });
    if (existing) {
      console.log(`[AUTH] Conflict: email ${data.email} is already registered`);
      throw new ConflictError('An account with this email already exists.', 'EMAIL_ALREADY_EXISTS');
    }

    // Hash password
    console.log(`[AUTH] Hashing password and preparing user record...`);
    const passwordHash = await bcrypt.hash(data.password, 12);

    // Create user
    const user = await prisma.user.create({
      data: {
        email: data.email,
        passwordHash,
        name: data.name,
      },
    });
    console.log(`[AUTH] Successfully created user record: ${user.id} (${user.email})`);

    const token = generateToken(user.id);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error: any) {
    console.error(`[AUTH] Registration failed: [${error.name || 'Error'}] ${error.message || error}`);
    if (error instanceof z.ZodError) {
      const message = error.errors.map(e => e.message).join(', ');
      next(new ValidationError(message, 'VALIDATION_ERROR'));
    } else {
      next(error);
    }
  }
}

export async function login(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const data = loginSchema.parse(req.body);
    console.log(`[AUTH] Login attempt for email: ${data.email}`);

    const user = await prisma.user.findUnique({ where: { email: data.email } });
    if (!user) {
      console.log(`[AUTH] Login failed: User ${data.email} not found`);
      throw new UnauthorizedError('Invalid email or password');
    }

    const valid = await bcrypt.compare(data.password, user.passwordHash);
    if (!valid) {
      console.log(`[AUTH] Login failed: Invalid password for ${data.email}`);
      throw new UnauthorizedError('Invalid email or password');
    }

    const token = generateToken(user.id);
    console.log(`[AUTH] User authenticated successfully: ${user.id}`);

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      const message = error.errors.map(e => e.message).join(', ');
      next(new ValidationError(message, 'VALIDATION_ERROR'));
    } else {
      next(error);
    }
  }
}

export async function me(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        dateOfBirth: true,
        gender: true,
        profilePhoto: true,
        createdAt: true,
      },
    });

    if (!user) {
      throw new UnauthorizedError('User not found');
    }

    res.json({ user });
  } catch (error) {
    next(error);
  }
}

export async function logout(_req: AuthRequest, res: Response) {
  res.json({ message: 'Logged out successfully' });
}
