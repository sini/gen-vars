# gen-vars

A den-agnostic, pure-Nix vars/secrets library. It owns the generator model, DAG ordering, a backend-agnostic plan, and a multi-target resolve interface. Impure execution is emitted, never run — the library produces plans, leaving the actual generation to a backend the consumer drives. See the design spec at [`~/Documents/papers/den-architecture/specs/2026-05-31-gen-vars-design.md`](~/Documents/papers/den-architecture/specs/2026-05-31-gen-vars-design.md).
