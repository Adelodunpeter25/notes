import { eq } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import { SignJWT, jwtVerify } from 'jose';
import { env } from 'cloudflare:workers';
import { db } from '@db/index';
import { users } from '@db/schema';
import type { LoginPayload, SignupPayload, AuthResponse } from '@custom-types/index';

const secretKey = () => new TextEncoder().encode(env.JWT_SECRET);

// HS256 with no expiry, same as the previous jsonwebtoken setup, so tokens
// already issued to devices keep working as long as JWT_SECRET is unchanged.
const signToken = (userId: string) =>
  new SignJWT({ userId }).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().sign(secretKey());

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

    if (!user) {
      throw new Error('Failed to create user');
    }

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      token: await signToken(user.id),
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

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      token: await signToken(user.id),
    };
  },

  async verifyToken(token: string): Promise<{ userId: string }> {
    try {
      const { payload } = await jwtVerify(token, secretKey(), { algorithms: ['HS256'] });
      if (typeof payload.userId !== 'string') throw new Error('bad payload');
      return { userId: payload.userId };
    } catch {
      throw new Error('Invalid token');
    }
  },
};
