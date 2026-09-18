export function parseOptions(argv) {
  const mode = argv[0];
  const args = new Set(argv.slice(1));
  const value = (name) => {
    const prefix = `${name}=`;
    return [...args]
      .find((item) => item.startsWith(prefix))
      ?.slice(prefix.length);
  };
  const projectId = value('--project');
  const confirmedProject = value('--confirm-project');
  const apply = args.has('--apply');
  const allowProduction = args.has('--allow-production');

  if (!['process-pending', 'purge'].includes(mode)) {
    throw new Error('Use process-pending or purge. Commands default to dry-run.');
  }
  if (!projectId || projectId !== confirmedProject) {
    throw new Error('Pass matching --project and --confirm-project values.');
  }
  if (apply && !projectId.startsWith('demo-') && !allowProduction) {
    throw new Error(
      'Production apply requires separate approval and --allow-production.',
    );
  }
  return {
    mode,
    projectId,
    apply,
    allowProduction,
    executionMode: apply ? 'apply' : 'dry-run',
  };
}
