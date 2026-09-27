/**
 * The small piece of the Vercel REST API that `:deploy` needs: make sure the
 * project exists in the team, and read back the production URL and deployment
 * id after a deploy. The CLI can create a project, but this path is
 * non-interactive and deterministic, and it never puts the token on a command
 * line.
 *
 * The token is only ever sent in the `Authorization` header; error messages
 * carry the HTTP status and the API's own message, never the header.
 */
const API = "https://api.vercel.com";

/** Bound on how much API text an error message may echo. */
const ERROR_LIMIT = 400;

async function request(token, method, pathname, body) {
  const response = await fetch(`${API}${pathname}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, text: await response.text() };
}

function apiError(what, response) {
  const detail = response.text.replaceAll(/\s+/g, " ").slice(0, ERROR_LIMIT);
  return new Error(`${what}: Vercel API returned ${response.status} ${detail}`);
}

function parseJson(text, what) {
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`${what}: Vercel API returned a non-JSON body`);
  }
}

function isRecord(value) {
  return typeof value === "object" && value !== null;
}

/**
 * Returns `{ id }` for the project `name` in `teamId`, creating it when it does
 * not exist yet.
 */
export async function ensureProject({ token, teamId, name }) {
  const scope = `?teamId=${encodeURIComponent(teamId)}`;
  const existing = await request(token, "GET", `/v9/projects/${encodeURIComponent(name)}${scope}`);
  if (existing.status === 200) {
    const project = parseJson(existing.text, "project lookup");
    if (!isRecord(project) || typeof project.id !== "string" || project.name !== name) {
      throw new Error(`project lookup: Vercel returned an unexpected project for ${name}`);
    }
    return { id: project.id, created: false };
  }
  if (existing.status !== 404) throw apiError("project lookup", existing);

  for (const version of ["v11", "v10"]) {
    const created = await request(token, "POST", `/${version}/projects${scope}`, { name });
    if (created.status === 200 || created.status === 201) {
      const project = parseJson(created.text, "project create");
      if (!isRecord(project) || typeof project.id !== "string" || project.name !== name) {
        throw new Error(`project create: Vercel returned an unexpected project for ${name}`);
      }
      return { id: project.id, created: true };
    }
    if (created.status !== 404 && created.status !== 405) throw apiError("project create", created);
  }
  throw new Error("project create: Vercel rejected both /v11/projects and /v10/projects");
}

/**
 * The latest production deployment of the project, as `{ id, url }`, and the
 * project's production alias when Vercel has assigned one. Retries briefly: the
 * alias is applied asynchronously right after the deploy.
 */
export async function productionTarget({ token, teamId, projectId, attempts = 5, delayMs = 2000 }) {
  const scope = `teamId=${encodeURIComponent(teamId)}`;
  let deployment;
  let alias = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const response = await request(
      token,
      "GET",
      `/v6/deployments?projectId=${encodeURIComponent(projectId)}&${scope}&limit=1&target=production`,
    );
    if (response.status !== 200) throw apiError("deployment lookup", response);
    const body = parseJson(response.text, "deployment lookup");
    const first = isRecord(body) && Array.isArray(body.deployments) ? body.deployments[0] : undefined;
    if (isRecord(first) && typeof first.uid === "string" && typeof first.url === "string") {
      deployment = { id: first.uid, url: `https://${first.url}` };
    }
    const projectResponse = await request(
      token,
      "GET",
      `/v9/projects/${encodeURIComponent(projectId)}?${scope}`,
    );
    if (projectResponse.status === 200) {
      const project = parseJson(projectResponse.text, "project lookup");
      const targets = isRecord(project) ? project.targets : undefined;
      const production = isRecord(targets) ? targets.production : undefined;
      const aliases = isRecord(production) ? production.alias : undefined;
      const firstAlias = Array.isArray(aliases) ? aliases[0] : undefined;
      if (typeof firstAlias === "string" && firstAlias.length > 0) alias = `https://${firstAlias}`;
    }
    if (deployment !== undefined && alias !== null) break;
    if (attempt + 1 < attempts) await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
  if (deployment === undefined) throw new Error("deployment lookup: no production deployment found");
  return { deployment, alias };
}
