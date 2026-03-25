export type AuthUser = {
  id: string;
  email: string;
  name?: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type SignupPayload = {
  email: string;
  password: string;
  name?: string;
};

export type LoginPayload = {
  email: string;
  password: string;
};

export type AuthResponse = {
  user: AuthUser;
  token: string;
};
