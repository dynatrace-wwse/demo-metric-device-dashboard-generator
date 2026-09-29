# Learnings

- OpenPipeline topology extraction on Gen3 requires builtin:openpipeline.bizevents.pipelines and builtin:openpipeline.bizevents.routing settings objects.
- The routing schema is a tenant-wide singleton (maxObjects=1) shared by every technology and every hand-built demo route — always merge a new entry in via scripts/apply-openpipeline-routing.sh, never `dtctl apply -f` a routing file directly, or you silently overwrite everyone else's rules.
- Keep map regions disabled using showRegions=false to avoid map data loading failures.
- Use event.provider filters on every dashboard query to keep scan volume predictable.
- Inject in 500-event chunks to stay under payload limits.
