import { useMemo, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";

import { Button, Card, Input } from "@/components/common";
import { useLoginMutation } from "@/hooks";

export function LoginCard() {
  const navigate = useNavigate();
  const loginMutation = useLoginMutation();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const emailValue = email.trim();

  const errors = useMemo(() => {
    const nextErrors: { email?: string; password?: string } = {};

    if (!emailValue) {
      nextErrors.email = "Email is required.";
    } else if (!/^\S+@\S+\.\S+$/.test(emailValue)) {
      nextErrors.email = "Enter a valid email address.";
    }

    if (!password) {
      nextErrors.password = "Password is required.";
    }

    return nextErrors;
  }, [emailValue, password]);

  const isValid = !errors.email && !errors.password;

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitted(true);

    if (!isValid) {
      return;
    }

    loginMutation.mutate(
      { email: emailValue, password },
      {
        onSuccess: () => {
          navigate("/", { replace: true });
        },
      },
    );
  };

  return (
    <Card className="w-full max-w-md space-y-4 p-6">
      <header className="space-y-1">
        <h1 className="text-xl font-semibold text-text">Login</h1>
        <p className="text-sm text-muted">Welcome back. Continue to your notes.</p>
      </header>

      <form className="space-y-3" onSubmit={submit} noValidate>
        <div className="space-y-1">
          <Input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.currentTarget.value)}
            placeholder="Email"
          />
          {submitted && errors.email ? <p className="text-xs text-danger">{errors.email}</p> : null}
        </div>

        <div className="space-y-1">
          <div className="relative">
            <Input
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={(event) => setPassword(event.currentTarget.value)}
              placeholder="Password"
              className="pr-11"
            />
            <button
              type="button"
              onClick={() => setShowPassword((value) => !value)}
              className="absolute inset-y-0 right-0 flex w-11 items-center justify-center text-muted transition-colors duration-200 ease-apple hover:text-text"
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
          {submitted && errors.password ? <p className="text-xs text-danger">{errors.password}</p> : null}
        </div>

        {loginMutation.isError ? (
          <p className="text-sm text-danger">{loginMutation.error.message}</p>
        ) : null}

        <Button className="w-full" type="submit" disabled={loginMutation.isPending || !isValid}>
          {loginMutation.isPending ? "Signing in..." : "Login"}
        </Button>
      </form>

      <p className="text-sm text-muted">
        No account yet?{" "}
        <Link className="text-accent hover:text-accent-soft" to="/signup">
          Create one
        </Link>
      </p>
    </Card>
  );
}
