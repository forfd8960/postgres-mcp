# src/services/ai_client.py
"""AI client services for SQL generation and validation."""
import logging
import re

from openai import AsyncOpenAI
from typing import Optional

logger = logging.getLogger("ai-client")

# System prompt for SQL generation
SQL_GENERATION_PROMPT = """你是一个 PostgreSQL 专家。用户想要查询数据库。

可用的数据库 Schema 信息:
{schema_info}

用户的查询需求: {user_query}

请生成对应的 PostgreSQL SELECT 语句。只返回 SQL 代码，不要其他解释。
如果无法生成有效的查询，返回 "ERROR: generate SQL failed"。

约束:
- 只使用 SELECT 语句
- 使用正确的 PostgreSQL 语法
- 列名使用双引号处理保留字
- 字符串使用单引号
"""

# System prompt for result validation
RESULT_VALIDATION_PROMPT = """你是一个数据库查询验证专家。
请判断给定的查询结果是否符合用户的原始查询需求。

用户原始查询: {user_query}
生成的 SQL: {sql}
查询结果预览: {result_preview}

只回答 "YES" 或 "NO"，以及简短的原因。
"""


class AIClient:
    """OpenAI client wrapper for pg-mcp."""

    def __init__(
        self,
        api_key: str,
        model: str = "gpt-4o-mini",
        base_url: Optional[str] = None,
        timeout: int = 30
    ):
        """Initialize the AI client.

        Args:
            api_key: OpenAI API key.
            model: Model name to use.
            base_url: Optional base URL for OpenAI-compatible APIs.
            timeout: Request timeout in seconds.
        """
        logger.info("Initializing AIClient with model: %s, base_url: %s", model, base_url)

        self.client = AsyncOpenAI(
            api_key=api_key,
            base_url=base_url
        )
        self.model = model
        self.timeout = timeout

    async def generate_sql(
        self,
        schema_info: str,
        user_query: str,
        system_prompt: Optional[str] = None
    ) -> str:
        """Generate an SQL statement from natural language.

        Args:
            schema_info: Formatted database schema information.
            user_query: The user's natural language query.
            system_prompt: Optional custom system prompt.

        Returns:
            The generated SQL statement or an error message.
        """

        logger.info("Generating SQL for user query: %s", user_query)

        if system_prompt is None:
            system_prompt = SQL_GENERATION_PROMPT.format(
                schema_info=schema_info,
                user_query=user_query
            )

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"Schema 信息:\n{schema_info}\n\n用户查询: {user_query}"}
                ],
                temperature=0.1,
                timeout=self.timeout
            )

            content = response.choices[0].message.content or ""
            sql = self._extract_sql(content)
            return sql
        except Exception as e:
            logger.error("AI SQL generation failed: %s", str(e))
            return "ERROR: generate SQL failed"

    def _extract_sql(self, content: str) -> str:
        """Extract SQL from LLM responses that may contain reasoning text.

        Prefers fenced ```sql blocks, then generic ``` blocks, then returns
        stripped content without <think> sections.
        """
        cleaned = re.sub(r"<think>.*?</think>", "", content, flags=re.DOTALL)

        match = re.search(r"```sql\s*(.*?)```", cleaned, flags=re.DOTALL | re.IGNORECASE)
        if match:
            return match.group(1).strip()

        match = re.search(r"```\s*(.*?)```", cleaned, flags=re.DOTALL)
        if match:
            return match.group(1).strip()

        return cleaned.strip()

    async def validate_result(
        self,
        user_query: str,
        sql: str,
        result_preview: str
    ) -> tuple[bool, str]:
        """Validate if query results match user expectations.

        Args:
            user_query: The original user query.
            sql: The generated SQL statement.
            result_preview: Preview of the query results.

        Returns:
            A tuple of (is_valid, reason).
        """
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": RESULT_VALIDATION_PROMPT},
                    {"role": "user", "content": f"用户原始查询: {user_query}\n生成的 SQL: {sql}\n查询结果预览: {result_preview}"}
                ],
                temperature=0.0,
                timeout=self.timeout
            )

            result = response.choices[0].message.content.strip()
            is_valid = result.upper().startswith("YES")
            reason = result[4:].strip() if not is_valid else ""

            return is_valid, reason
        except Exception as e:
            return False, f"验证失败: {str(e)}"
