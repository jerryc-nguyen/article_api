# Backend Architecture Rules

## Module Structure
- `app/modules/<module>/` — each module is a **bounded context** for business logic and API
- Large modules organize by **feature** (usecase), then by layer: `services/`, `queries/`, `serializers/`, `api.rb`
- Small modules (1-2 services) can stay flat without feature sub-groups
- **Models and persistence stay in Rails convention** (`app/models/`, `db/migrate/`) — domain entities are shared across modules, not owned by one

```
app/modules/order/
  api.rb                            # Order::Api < Grape::API
  placement/                        # Feature
    api.rb                          #   Order::Placement::Api
    services/place_order.rb         #   Order::Placement::Services::PlaceOrder
    queries/order_search.rb         #   Order::Placement::Queries::OrderSearch
    serializers/order_serializer.rb #   Order::Placement::Serializers::OrderSerializer
```

```
app/models/order.rb                 # ActiveRecord — Rails convention
db/migrate/xxx_create_orders.rb
```

**Namespace:** `Module::Feature::Layer::Class` (e.g. `Order::Placement::Services::PlaceOrder`)

## Layer Rules
| Layer | Location | Responsibility |
|---|---|---|
| **Grape API** (`api.rb`) | `app/modules/<m>/` | Parse request, validation, pagination, serialization. NO business logic |
| **Services** | `app/modules/<m>/services/` | Business logic, orchestration. Pure Ruby, no HTTP knowledge |
| **Queries** | `app/modules/<m>/queries/` | Read operations, return `ActiveRecord::Relation`. Pure, no HTTP |
| **Serializers** | `app/modules/<m>/serializers/` | `Grape::Entity` — format response |
| **Models** | `app/models/` | ActiveRecord, data persistence. Rails convention, shared across modules |

## Dependency Direction
```
API → Services/Queries → Models (app/models/)
                          ↑
Infrastructure ───────────┘
(Never: Domain/Model → Infrastructure)
```

## Public Interface Convention
- Only `Public/` sub-module is the public interface for other features/modules
- Cross-feature/module calls must go through `Public::`

```ruby
# ✅ Correct
Order::Placement::Public::PlaceOrder.call(params)
# ❌ Wrong — calling internal layers
Order::Placement::Services::PlaceOrder.call(params)
```

## Code Flow
```
GET /api/v1/article_management?status=draft
  → ArticleManagement::Api#index
    → ArticleManagement::Queries::ArticleSearch.call(params)        # Relation
    → present items, with: ArticleManagement::Serializers::ArticleSerializer
```

## Communication
- Sync: direct calls via public services
- Async: domain events

## Naming
- Files: `snake_case.rb` (Rails) / `kebab-case.ts` (Node)
- Classes: `PascalCase`
- Methods: `snake_case` (Ruby) / `camelCase` (TS)

## Testing
- Unit test services + domain objects
- Integration test API endpoints
- No mock DB unless necessary

## Forbidden
- Business logic in API layer
- Direct model call from API — always go through Service or Query
- Cross-module table join
- Calling `Services::` / `Queries::` of another feature — use `Public::` instead
- Raw SQL in application/domain layer
