export type User = {
  id: string;
  email: string;
  name?: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type LoginPayload = {
  email: string;
  password: string;
};

export type SignupPayload = {
  email: string;
  password: string;
  name?: string;
};

export type AuthResponse = {
  user: User;
  token: string;
};
