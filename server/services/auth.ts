import { eq } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from '@db/index';
import { users } from '@db/schema';
import type { LoginPayload, SignupPayload, AuthResponse } from '@types/index';

const JWT_SECRET = process.env.JWT_SECRET!;

export const authService = {
  async signup(payload: SignupPayload): Promise<AuthResponse> {
    const existingUser = await db.query.users.findFirst({
      where: eq(users.email, payload.email),
    });

    if (existingUser) {
      throw new Error('User already exists');
    }

    const hashedPassword = await bcrypt.hash(payload.password, 10);

    const [user] = await db.insert(users).values({
      email: payload.email,
      password: hashedPassword,
      name: payload.name,
    }).returning();

    const token = jwt.sign({ userId: user.id }, JWT_SECRET);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      token,
    };
  },

  async login(payload: LoginPayload): Promise<AuthResponse> {
    const user = await db.query.users.findFirst({
      where: eq(users.email, payload.email),
    });

    if (!user) {
      throw new Error('Invalid credentials');
    }

    const isValid = await bcrypt.compare(payload.password, user.password);

    if (!isValid) {
      throw new Error('Invalid credentials');
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      token,
    };
  },

  verifyToken(token: string): { userId: string } {
    try {
      return jwt.verify(token, JWT_SECRET) as { userId: string };
    } catch {
      throw new Error('Invalid token');
    }
  },
};
